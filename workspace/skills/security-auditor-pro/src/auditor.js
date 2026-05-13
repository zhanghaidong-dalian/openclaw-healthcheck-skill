/**
 * Security Auditor Pro - 核心审计引擎
 * OpenClaw安全审计技能
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const rules = require('./rules');
const notifier = require('./notifier');
const reporter = require('./reporter');

class SecurityAuditor {
  constructor(config = {}) {
    this.config = {
      riskThreshold: config.riskThreshold || 70,
      autoScan: config.autoScan !== false,
      notifications: config.notifications || {},
      ...config
    };
    
    this.auditResults = [];
    this.sessionRisks = [];
  }

  /**
   * 审计指定技能
   * @param {string} skillPath - 技能路径或名称
   * @returns {Object} 审计结果
   */
  async audit(skillPath) {
    console.log(`🛡️ 开始审计技能: ${skillPath}`);
    
    // 确定技能路径
    const actualPath = this.resolveSkillPath(skillPath);
    
    if (!actualPath) {
      return {
        success: false,
        error: `无法找到技能: ${skillPath}`
      };
    }

    // 执行各项检测
    const results = {
      skillName: path.basename(actualPath),
      skillPath: actualPath,
      timestamp: new Date().toISOString(),
      scans: {},
      risks: [],
      score: 100
    };

    // 1. 静态代码分析
    results.scans.staticAnalysis = await this.scanStaticCode(actualPath);
    results.risks.push(...results.scans.staticAnalysis.risks);
    
    // 2. 权限分析
    results.scans.permissionAnalysis = await this.scanPermissions(actualPath);
    results.risks.push(...results.scans.permissionAnalysis.risks);
    
    // 3. 依赖分析
    results.scans.dependencyAnalysis = await this.scanDependencies(actualPath);
    results.risks.push(...results.scans.dependencyAnalysis.risks);
    
    // 4. 网络行为分析
    results.scans.networkAnalysis = await this.scanNetworkBehavior(actualPath);
    results.risks.push(...results.scans.networkAnalysis.risks);
    
    // 5. 计算总分
    results.score = this.calculateScore(results.risks);
    results.riskLevel = this.getRiskLevel(results.score);
    
    // 生成报告
    results.report = this.generateReport(results);
    
    // 存储结果
    this.auditResults.push(results);
    
    // 检查是否需要告警
    if (results.score < this.config.riskThreshold) {
      await this.triggerAlert(results);
    }
    
    return results;
  }

  /**
   * 解析技能路径
   */
  resolveSkillPath(skillName) {
    const searchPaths = [
      path.join(process.cwd(), 'skills', skillName),
      path.join(process.env.HOME || '', '.openclaw/skills', skillName),
      path.join(process.env.HOME || '', '.openclaw/workspace/skills', skillName),
      path.join(__dirname, '..', skillName)
    ];
    
    for (const p of searchPaths) {
      if (fs.existsSync(p)) {
        return p;
      }
    }
    
    // 尝试作为ClawHub技能
    try {
      const clawhubPath = path.join(process.env.HOME || '', '.openclaw/skills');
      if (fs.existsSync(clawhubPath)) {
        const skills = fs.readdirSync(clawhubPath);
        const match = skills.find(s => s.toLowerCase().includes(skillName.toLowerCase()));
        if (match) {
          return path.join(clawhubPath, match);
        }
      }
    } catch (e) {
      // 忽略错误
    }
    
    return null;
  }

  /**
   * 静态代码分析
   */
  async scanStaticCode(skillPath) {
    const risks = [];
    const findings = [];
    
    // 扫描所有代码文件
    const codeFiles = this.findCodeFiles(skillPath);
    
    for (const file of codeFiles) {
      const content = fs.readFileSync(file, 'utf-8');
      const relativePath = path.relative(skillPath, file);
      
      // 检查高风险规则
      for (const rule of rules.highRisk) {
        if (rule.pattern.test(content)) {
          risks.push({
            rule: rule.id,
            severity: 'high',
            message: rule.message,
            file: relativePath,
            mitigation: rule.mitigation
          });
          findings.push(`🔴 ${rule.id}: ${rule.message} (${relativePath})`);
        }
      }
      
      // 检查中风险规则
      for (const rule of rules.mediumRisk) {
        if (rule.pattern.test(content)) {
          risks.push({
            rule: rule.id,
            severity: 'medium',
            message: rule.message,
            file: relativePath,
            mitigation: rule.mitigation
          });
          findings.push(`🟠 ${rule.id}: ${rule.message} (${relativePath})`);
        }
      }
      
      // 检查低风险规则
      for (const rule of rules.lowRisk) {
        if (rule.pattern.test(content)) {
          risks.push({
            rule: rule.id,
            severity: 'low',
            message: rule.message,
            file: relativePath,
            mitigation: rule.mitigation
          });
          findings.push(`🟡 ${rule.id}: ${rule.message} (${relativePath})`);
        }
      }
    }
    
    return {
      risks,
      findings,
      fileCount: codeFiles.length
    };
  }

  /**
   * 权限分析
   */
  async scanPermissions(skillPath) {
    const risks = [];
    const findings = [];
    
    // 读取 SKILL.md
    const skillMdPath = path.join(skillPath, 'SKILL.md');
    if (fs.existsSync(skillMdPath)) {
      const content = fs.readFileSync(skillMdPath, 'utf-8');
      
      // 检查权限声明
      const permissionPatterns = [
        { pattern: /file.*system|filesystem|file.*read|file.*write/gi, permission: '文件系统访问' },
        { pattern: /network|internet|http|request/gi, permission: '网络访问' },
        { pattern: /shell|command|exec|terminal/gi, permission: 'Shell命令执行' },
        { pattern: /env|environment|process\./gi, permission: '环境变量访问' },
        { pattern: /key|credential|secret|password|token/gi, permission: '密钥凭证访问' }
      ];
      
      for (const { pattern, permission } of permissionPatterns) {
        if (pattern.test(content)) {
          findings.push(`📋 声明权限: ${permission}`);
        }
      }
      
      // 检查是否有未声明的敏感权限
      if (/eval|exec\s*\(|child_process/gi.test(content) && !/shell.*command/gi.test(content)) {
        risks.push({
          rule: 'PERM001',
          severity: 'high',
          message: '检测到命令执行能力，但SKILL.md中未明确说明',
          mitigation: '在SKILL.md中明确说明为何需要此权限'
        });
      }
    }
    
    return { risks, findings };
  }

  /**
   * 依赖分析
   */
  async scanDependencies(skillPath) {
    const risks = [];
    const findings = [];
    
    // 检查 package.json
    const pkgPath = path.join(skillPath, 'package.json');
    if (fs.existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
        const allDeps = { 
          ...pkg.dependencies, 
          ...pkg.devDependencies 
        };
        
        findings.push(`📦 依赖数量: ${Object.keys(allDeps).length}`);
        
        // 检查已知风险的依赖
        for (const [dep, version] of Object.entries(allDeps)) {
          if (rules.knownVulnerableDeps[dep]) {
            risks.push({
              rule: 'DEP001',
              severity: 'high',
              message: `依赖 ${dep} 存在已知安全漏洞: ${rules.knownVulnerableDeps[dep]}`,
              mitigation: `升级 ${dep} 到最新版本或寻找替代方案`
            });
          }
        }
      } catch (e) {
        findings.push(`⚠️ 无法解析 package.json: ${e.message}`);
      }
    }
    
    // 检查 requirements.txt (Python)
    const reqPath = path.join(skillPath, 'requirements.txt');
    if (fs.existsSync(reqPath)) {
      const content = fs.readFileSync(reqPath, 'utf-8');
      findings.push(`🐍 检测到 Python 依赖`);
      
      // 简单检查（实际应该对接CVE数据库）
      if (/requests\s*<|urllib\s*</gi.test(content)) {
        risks.push({
          rule: 'DEP002',
          severity: 'medium',
          message: 'Python依赖版本可能存在安全风险',
          mitigation: '确保使用最新版本的依赖'
        });
      }
    }
    
    return { risks, findings };
  }

  /**
   * 网络行为分析
   */
  async scanNetworkBehavior(skillPath) {
    const risks = [];
    const findings = [];
    
    const codeFiles = this.findCodeFiles(skillPath);
    
    const networkPatterns = [
      { pattern: /fetch\s*\(|axios|http\.request|request\s*\(/gi, name: 'HTTP请求' },
      { pattern: /WebSocket|ws\s*\(/gi, name: 'WebSocket连接' },
      { pattern: /dns\.|lookup\(/gi, name: 'DNS查询' },
      { pattern: /sendgrid|mailgun|smtp/gi, name: '邮件发送' }
    ];
    
    for (const file of codeFiles) {
      const content = fs.readFileSync(file, 'utf-8');
      
      for (const { pattern, name } of networkPatterns) {
        if (pattern.test(content)) {
          findings.push(`🌐 网络行为: ${name} (${path.basename(file)})`);
        }
      }
      
      // 检查硬编码的URL
      const urlMatches = content.match(/https?:\/\/[^\s"'<>()]+/gi) || [];
      const uniqueUrls = [...new Set(urlMatches)];
      
      if (uniqueUrls.length > 0) {
        findings.push(`🔗 涉及域名: ${uniqueUrls.map(u => new URL(u).hostname).join(', ')}`);
        
        // 检查可疑域名
        for (const url of uniqueUrls) {
          try {
            const hostname = new URL(url).hostname;
            if (rules.suspiciousDomains.some(d => hostname.includes(d))) {
              risks.push({
                rule: 'NET001',
                severity: 'high',
                message: `连接到可疑域名: ${hostname}`,
                mitigation: '确认该域名的合法性'
              });
            }
          } catch (e) {
            // 忽略无效URL
          }
        }
      }
    }
    
    return { risks, findings };
  }

  /**
   * 查找所有代码文件
   */
  findCodeFiles(dir, files = []) {
    if (!fs.existsSync(dir)) return files;
    
    const items = fs.readdirSync(dir, { withFileTypes: true });
    
    for (const item of items) {
      const fullPath = path.join(dir, item.name);
      
      // 跳过特定目录
      if (item.isDirectory()) {
        if (!['node_modules', '.git', 'tests', '__pycache__'].includes(item.name)) {
          this.findCodeFiles(fullPath, files);
        }
      } else {
        const ext = path.extname(item.name).toLowerCase();
        if (['.js', '.ts', '.py', '.sh', '.json'].includes(ext)) {
          files.push(fullPath);
        }
      }
    }
    
    return files;
  }

  /**
   * 计算风险评分
   */
  calculateScore(risks) {
    let score = 100;
    
    for (const risk of risks) {
      switch (risk.severity) {
        case 'high':
          score -= 25;
          break;
        case 'medium':
          score -= 10;
          break;
        case 'low':
          score -= 5;
          break;
      }
    }
    
    return Math.max(0, score);
  }

  /**
   * 获取风险等级
   */
  getRiskLevel(score) {
    if (score >= 90) return { level: 'safe', emoji: '🟢', text: '安全' };
    if (score >= 70) return { level: 'caution', emoji: '🟡', text: '建议注意' };
    if (score >= 50) return { level: 'warning', emoji: '🟠', text: '谨慎使用' };
    return { level: 'danger', emoji: '🔴', text: '不建议安装' };
  }

  /**
   * 生成审计报告
   */
  generateReport(results) {
    const { score, riskLevel, risks, scans } = results;
    
    let report = `
🛡️ 安全审计报告

技能名称: ${results.skillName}
审计时间: ${new Date(results.timestamp).toLocaleString()}
安全评分: ${score}/100 ${riskLevel.emoji} ${riskLevel.text}

`;
    
    // 高风险项
    const highRisks = risks.filter(r => r.severity === 'high');
    if (highRisks.length > 0) {
      report += `🔴 高风险项 (${highRisks.length}项):\n`;
      for (const risk of highRisks) {
        report += `  ⚠️ ${risk.message}\n`;
        if (risk.file) report += `     位置: ${risk.file}\n`;
        report += `     建议: ${risk.mitigation}\n\n`;
      }
    }
    
    // 中风险项
    const mediumRisks = risks.filter(r => r.severity === 'medium');
    if (mediumRisks.length > 0) {
      report += `🟠 中风险项 (${mediumRisks.length}项):\n`;
      for (const risk of mediumRisks) {
        report += `  ⚠️ ${risk.message}\n`;
        report += `     建议: ${risk.mitigation}\n\n`;
      }
    }
    
    // 低风险项
    const lowRisks = risks.filter(r => r.severity === 'low');
    if (lowRisks.length > 0) {
      report += `🟡 低风险项 (${lowRisks.length}项):\n`;
      for (const risk of lowRisks) {
        report += `  ℹ️ ${risk.message}\n`;
      }
    }
    
    // 汇总
    if (risks.length === 0) {
      report += `
✅ 未发现明显风险，该技能可以放心使用。
`;
    } else {
      report += `
📋 总体建议: ${riskLevel.text === '安全' ? '可以放心安装使用' : '请谨慎操作'}
`;
    }
    
    return report;
  }

  /**
   * 触发告警
   */
  async triggerAlert(results) {
    console.log(`⚠️ 安全告警: ${results.skillName} 评分 ${results.score} 分`);
    
    if (this.config.notifications.feishu?.enabled) {
      await notifier.sendFeishu({
        webhook: this.config.notifications.feishu.webhook,
        title: `🔴 安全告警: ${results.skillName}`,
        content: results.report
      });
    }
    
    if (this.config.notifications.email?.enabled) {
      await notifier.sendEmail({
        to: this.config.notifications.email.to,
        subject: `[Security Auditor] 安全告警: ${results.skillName}`,
        body: results.report
      });
    }
  }

  /**
   * 生成定期报告
   */
  async generatePeriodicReport(type = 'daily') {
    return reporter.generateReport(this.auditResults, type);
  }
}

module.exports = SecurityAuditor;
