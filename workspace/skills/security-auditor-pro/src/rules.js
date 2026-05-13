/**
 * Security Auditor Pro - 检测规则库
 * 包含高、中、低风险规则以及已知漏洞依赖
 */

const rules = {
  // 高风险规则 - 25分/项
  highRisk: [
    {
      id: 'HR001',
      name: 'SSH密钥目录访问',
      pattern: /\.ssh|[\/\\]\.ssh|~\/\.ssh/gi,
      message: '尝试访问SSH密钥目录',
      mitigation: '确认技能是否需要管理SSH密钥'
    },
    {
      id: 'HR002',
      name: 'AWS凭证访问',
      pattern: /\.aws|[\/\\]\.aws|~\/\.aws|\.credentials/gi,
      message: '尝试访问AWS凭证目录',
      mitigation: '确认是否需要AWS访问权限'
    },
    {
      id: 'HR003',
      name: 'GPG密钥访问',
      pattern: /\.gnupg|[\/\\]\.gnupg|~\/\.gnupg/gi,
      message: '尝试访问GPG密钥目录',
      mitigation: '确认是否需要加密操作'
    },
    {
      id: 'HR004',
      name: 'Shell命令执行',
      pattern: /child_process\.exec|child_process\.execSync|subprocess\.run\(|Shell\(|\.execute\(/gi,
      message: '包含Shell命令执行功能',
      mitigation: '确认命令执行的具体用途'
    },
    {
      id: 'HR005',
      name: '动态代码执行',
      pattern: /eval\s*\(|exec\s*\(|new Function\(|compile\s*\(/gi,
      message: '包含动态代码执行功能',
      mitigation: '这可能带来严重安全风险，谨慎使用'
    },
    {
      id: 'HR006',
      name: 'Base64编码数据外发',
      pattern: /toString\s*\(\s*['"]base64|Buffer\.from.*base64/gi,
      message: '检测到Base64编码数据传输',
      mitigation: '确认数据传输的合法性'
    },
    {
      id: 'HR007',
      name: '隐蔽数据传输',
      pattern: /fetch\s*\([^)]*https?:\/\/[^\s]*\.(xyz|top|work|gq|ml|tk|click|loan)[^"\s]*/gi,
      message: '尝试向可疑域名发送数据',
      mitigation: '立即停止安装并举报该技能'
    },
    {
      id: 'HR008',
      name: '敏感文件读取',
      pattern: /fs\.readFileSync\([^)]*(\.pem|\.key|\.p12|\.pfx|passwd|shadow|etc\/passwd)/gi,
      message: '尝试读取敏感文件',
      mitigation: '确认是否需要读取这些文件'
    },
    {
      id: 'HR009',
      name: '环境变量泄露',
      pattern: /process\.env\.(AWS_|AZURE_|GOOGLE_|STRIPE_|SECRET_|PRIVATE_)|os\.environ.*KEY|os\.environ.*SECRET/gi,
      message: '尝试访问敏感环境变量',
      mitigation: '确认是否需要访问这些凭据'
    },
    {
      id: 'HR010',
      name: 'Cookie/Token窃取',
      pattern: /document\.cookie|localStorage\.setItem|navigator\.credential/gi,
      message: '尝试访问或存储认证凭据',
      mitigation: '确认凭据使用的合法性'
    }
  ],

  // 中风险规则 - 10分/项
  mediumRisk: [
    {
      id: 'MR001',
      name: '环境变量读取',
      pattern: /process\.env|os\.environ|getenv\(/gi,
      message: '读取环境变量',
      mitigation: '确认需要读取哪些环境变量'
    },
    {
      id: 'MR002',
      name: '配置文件读取',
      pattern: /fs\.readFileSync\([^)]*(\.json|\.yaml|\.yml|\.env|\.toml|\.ini)[^)]*\)/gi,
      message: '读取配置文件',
      mitigation: '确认配置文件的用途'
    },
    {
      id: 'MR003',
      name: '代码混淆',
      pattern: /function\s*\([^\)]*\)\s*\{[^}]{500,}\}|eval\s*\(function\(|packer|uglify/gi,
      message: '检测到混淆或压缩代码',
      mitigation: '建议使用源码版本或审查混淆后的代码'
    },
    {
      id: 'MR004',
      name: '文件写入操作',
      pattern: /fs\.writeFileSync|fs\.appendFileSync|\.write\(|>\s*\/|>>\s*\//gi,
      message: '包含文件写入功能',
      mitigation: '确认写入的文件和目录'
    },
    {
      id: 'MR005',
      name: '子进程创建',
      pattern: /child_process\.spawn|child_process\.spawnSync|Process\(|subprocess\.Popen/gi,
      message: '创建子进程',
      mitigation: '确认子进程的用途'
    },
    {
      id: 'MR006',
      name: '外部图片加载',
      pattern: /<img[^>]+src\s*=\s*["']?https?:|background(-image)?:\s*url\(/gi,
      message: '加载外部图片资源',
      mitigation: '确认图片来源的可靠性'
    },
    {
      id: 'MR007',
      name: 'HTTP请求发送',
      pattern: /http\.request|http\.get|http\.post|request\(|axios\.|got\(|node-fetch/gi,
      message: '发起网络请求',
      mitigation: '确认请求的域名和用途'
    },
    {
      id: 'MR008',
      name: '端口扫描行为',
      pattern: /net\.connect|socket\.connect|port.*scan|scanner/gi,
      message: '包含网络端口操作',
      mitigation: '确认网络连接的目的'
    }
  ],

  // 低风险规则 - 5分/项
  lowRisk: [
    {
      id: 'LR001',
      name: '用户目录访问',
      pattern: /~\/|process\.env\.HOME|process\.env\.USERPROFILE|os\.homedir\(\)/gi,
      message: '访问用户主目录',
      mitigation: '这是正常功能，无需担忧'
    },
    {
      id: 'LR002',
      name: '文件系统操作',
      pattern: /fs\.|path\.join|path\.resolve|os\.tmpdir\(\)/gi,
      message: '使用文件系统API',
      mitigation: '这是正常功能，无需担忧'
    },
    {
      id: 'LR003',
      name: '进程信息读取',
      pattern: /process\.pid|process\.cwd\(\)|os\.platform\(\)|os\.arch\(\)/gi,
      message: '读取进程或系统信息',
      mitigation: '这是正常功能，无需担忧'
    },
    {
      id: 'LR004',
      name: '日志记录',
      pattern: /console\.(log|info|warn|error)|logger\.|log4j|winston|bunyan/gi,
      message: '包含日志记录功能',
      mitigation: '这是正常功能，无需担忧'
    },
    {
      id: 'LR005',
      name: '时间操作',
      pattern: /Date\.|moment\.|dayjs\.|luxon\.|new Date\(\)/gi,
      message: '处理日期时间',
      mitigation: '这是正常功能，无需担忧'
    }
  ],

  // 已知存在漏洞的依赖
  knownVulnerableDeps: {
    'lodash': 'CVE-2021-23337, CVE-2020-8203',
    'moment': 'CVE-2022-24785',
    'axios': 'CVE-2021-3749, CVE-2020-28168',
    'node-fetch': 'CVE-2022-0235',
    'express': 'CVE-2022-24999, CVE-2022-24828',
    'jsonwebtoken': 'CVE-2022-23529',
    'jose': 'CVE-2023-44487',
    'minimist': 'CVE-2021-44906',
    'shell-quote': 'CVE-2021-42740',
    'tmpl': 'CVE-2020-7598',
    'requests': 'CVE-2023-32681',
    'urllib': 'CVE-2022-31017',
    'pillow': 'CVE-2022-45198'
  },

  // 可疑域名列表
  suspiciousDomains: [
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'click',
    'tracker',
    'analytics',
    'telemetry'
  ]
};

module.exports = rules;
