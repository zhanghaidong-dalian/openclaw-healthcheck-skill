/**
 * Security Auditor Pro - 报告生成模块
 * 生成周期性和详细的安全审计报告
 */

const fs = require('fs');
const path = require('path');

const reporter = {
  /**
   * 生成周期报告
   */
  generateReport(auditResults, type = 'daily') {
    const now = new Date();
    const stats = this.calculateStats(auditResults);
    
    let report = '';
    let title = '';
    
    switch (type) {
      case 'daily':
        title = `📊 日安全审计报告 - ${now.toLocaleDateString()}`;
        break;
      case 'weekly':
        title = `📊 周安全审计报告 - 第${Math.ceil(now.getDate() / 7)}周`;
        break;
      case 'monthly':
        title = `📊 月安全审计报告 - ${now.getFullYear()}年${now.getMonth() + 1}月`;
        break;
      default:
        title = '📊 安全审计报告';
    }
    
    report += `
${'='.repeat(50)}
${title}
${'='.repeat(50)}

生成时间: ${now.toLocaleString()}

📈 审计概况
${'-'.repeat(30)}
`;
    
    if (stats.total === 0) {
      report += `
暂无审计数据。请先使用 audit 命令审计技能。
`;
    } else {
      report += `
总审计次数: ${stats.total}
技能数量: ${stats.uniqueSkills}
高风险发现: ${stats.highRisks}
中风险发现: ${stats.mediumRisks}
低风险发现: ${stats.lowRisks}
`;
      
      // 风险等级分布
      const safeCount = stats.byLevel.safe || 0;
      const cautionCount = stats.byLevel.caution || 0;
      const warningCount = stats.byLevel.warning || 0;
      const dangerCount = stats.byLevel.danger || 0;
      
      report += `
风险等级分布:
  🟢 安全 (90-100分): ${safeCount} (${((safeCount / stats.total) * 100).toFixed(1)}%)
  🟡 注意 (70-89分): ${cautionCount} (${((cautionCount / stats.total) * 100).toFixed(1)}%)
  🟠 谨慎 (50-69分): ${warningCount} (${((warningCount / stats.total) * 100).toFixed(1)}%)
  🔴 危险 (0-49分): ${dangerCount} (${((dangerCount / stats.total) * 100).toFixed(1)}%)
`;

      // 平均分
      const avgScore = stats.total > 0 
        ? (stats.scores.reduce((a, b) => a + b, 0) / stats.scores.length).toFixed(1)
        : 0;
      
      report += `
平均安全评分: ${avgScore}/100
`;
      
      // 高风险技能列表
      if (stats.dangerousSkills.length > 0) {
        report += `
⚠️ 需要关注的技能:
${'-'.repeat(30)}
`;
        for (const skill of stats.dangerousSkills) {
          report += `  • ${skill.name}: ${skill.score}分\n`;
          for (const risk of skill.risks.slice(0, 3)) {
            report += `    - ${risk.message}\n`;
          }
        }
      }
      
      // 最近审计记录
      report += `
📝 最近审计记录:
${'-'.repeat(30)}
`;
      const recent = auditResults.slice(-5).reverse();
      for (const result of recent) {
        const emoji = result.score >= 90 ? '🟢' : result.score >= 70 ? '🟡' : result.score >= 50 ? '🟠' : '🔴';
        report += `  ${emoji} ${result.skillName}: ${score}/100 - ${new Date(result.timestamp).toLocaleString()}\n`;
      }
    }
    
    report += `
${'='.repeat(50)}
由 Security Auditor Pro 自动生成
${'='.repeat(50)}
`;
    
    return report;
  },

  /**
   * 计算统计数据
   */
  calculateStats(auditResults) {
    const stats = {
      total: auditResults.length,
      uniqueSkills: new Set(auditResults.map(r => r.skillName)).size,
      highRisks: 0,
      mediumRisks: 0,
      lowRisks: 0,
      scores: [],
      byLevel: {},
      dangerousSkills: []
    };

    for (const result of auditResults) {
      stats.scores.push(result.score);
      
      // 统计风险数量
      for (const risk of result.risks) {
        if (risk.severity === 'high') stats.highRisks++;
        else if (risk.severity === 'medium') stats.mediumRisks++;
        else if (risk.severity === 'low') stats.lowRisks++;
      }
      
      // 统计风险等级
      const level = result.riskLevel.level;
      stats.byLevel[level] = (stats.byLevel[level] || 0) + 1;
      
      // 记录高风险技能
      if (result.score < 50) {
        stats.dangerousSkills.push({
          name: result.skillName,
          score: result.score,
          risks: result.risks
        });
      }
    }

    return stats;
  },

  /**
   * 导出报告为文件
   */
  async exportToFile(auditResults, outputPath, format = 'markdown') {
    const report = this.generateReport(auditResults);
    
    // 确保目录存在
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    
    if (format === 'markdown') {
      fs.writeFileSync(outputPath, report, 'utf-8');
    } else if (format === 'json') {
      const jsonReport = {
        generatedAt: new Date().toISOString(),
        stats: this.calculateStats(auditResults),
        results: auditResults
      };
      fs.writeFileSync(outputPath, JSON.stringify(jsonReport, null, 2), 'utf-8');
    }
    
    console.log(`📄 报告已导出到: ${outputPath}`);
    return outputPath;
  },

  /**
   * 生成风险趋势数据（用于图表）
   */
  generateTrendData(auditResults, days = 30) {
    const now = new Date();
    const startDate = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    
    const dailyStats = {};
    
    for (const result of auditResults) {
      const date = new Date(result.timestamp).toLocaleDateString();
      
      if (!dailyStats[date]) {
        dailyStats[date] = {
          date,
          count: 0,
          avgScore: 0,
          scores: []
        };
      }
      
      dailyStats[date].count++;
      dailyStats[date].scores.push(result.score);
    }
    
    // 计算每日平均分
    const trend = Object.values(dailyStats).map(day => ({
      date: day.date,
      count: day.count,
      avgScore: day.scores.length > 0 
        ? (day.scores.reduce((a, b) => a + b, 0) / day.scores.length).toFixed(1)
        : 0
    }));
    
    return trend;
  }
};

module.exports = reporter;
