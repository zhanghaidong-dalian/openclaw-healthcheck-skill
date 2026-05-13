#!/usr/bin/env node

/**
 * Security Auditor Pro - CLI入口
 * OpenClaw安全审计技能命令行工具
 */

const SecurityAuditor = require('./src/auditor');
const reporter = require('./src/reporter');

// 加载配置
let config = {};
try {
  const configPath = require('path').join(__dirname, 'config.json');
  config = require(configPath);
} catch (e) {
  // 使用默认配置
}

// CLI处理
const args = process.argv.slice(2);
const command = args[0];

async function main() {
  const auditor = new SecurityAuditor(config);
  
  switch (command) {
    case 'audit':
      // 审计指定技能
      const skillName = args[1] || args[0];
      if (!skillName) {
        console.log('用法: security-auditor audit <技能名称或路径>');
        process.exit(1);
      }
      console.log(`🔍 正在审计: ${skillName}`);
      const result = await auditor.audit(skillName);
      console.log(result.report);
      break;
      
    case 'report':
      // 生成报告
      const reportType = args[1] || 'daily';
      console.log(`📊 生成${reportType}报告...`);
      const report = auditor.generatePeriodicReport(reportType);
      console.log(report);
      break;
      
    case 'export':
      // 导出报告到文件
      const outputPath = args[1] || './security-report.md';
      await auditor.auditResults.length > 0 
        ? auditor.exportToFile(auditor.auditResults, outputPath)
        : console.log('暂无审计数据');
      break;
      
    case 'interactive':
      // 交互式模式
      await interactiveMode(auditor);
      break;
      
    default:
      showHelp();
  }
}

/**
 * 交互式模式
 */
async function interactiveMode(auditor) {
  const readline = require('readline');
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  console.log(`
🛡️ Security Auditor Pro - 交互模式
${'='.repeat(40)}
请输入要审计的技能名称（或输入 'help' 查看帮助）
  `);
  
  rl.on('line', async (line) => {
    const input = line.trim();
    
    if (!input) return;
    
    if (input === 'quit' || input === 'exit') {
      console.log('👋 再见!');
      process.exit(0);
    }
    
    if (input === 'help') {
      showHelp();
      return;
    }
    
    if (input === 'report') {
      console.log(auditor.generatePeriodicReport('daily'));
      return;
    }
    
    // 执行审计
    console.log(`\n🔍 正在审计: ${input}\n`);
    const result = await auditor.audit(input);
    console.log(result.report);
  });
}

/**
 * 显示帮助
 */
function showHelp() {
  console.log(`
🛡️ Security Auditor Pro

用法:
  security-auditor audit <技能名称>    审计指定技能
  security-auditor report [类型]        生成报告 (daily/weekly/monthly)
  security-auditor export [路径]         导出报告到文件
  security-auditor interactive         交互式模式

示例:
  security-auditor audit github-skill
  security-auditor audit ./my-skill
  security-auditor report weekly
  security-auditor export ./report.md
`);
}

main().catch(console.error);
