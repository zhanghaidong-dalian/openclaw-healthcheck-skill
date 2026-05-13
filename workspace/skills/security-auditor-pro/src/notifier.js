/**
 * Security Auditor Pro - 通知模块
 * 支持飞书、企业微信、邮件等告警通知
 */

const https = require('https');
const http = require('http');

const notifier = {
  /**
   * 发送飞书机器人消息
   */
  async sendFeishu({ webhook, title, content }) {
    if (!webhook) {
      console.log('⚠️ 飞书Webhook未配置');
      return false;
    }

    try {
      // 构建消息内容
      const message = {
        msg_type: 'interactive',
        card: {
          header: {
            title: {
              tag: 'plain_text',
              content: title
            },
            template: 'red'
          },
          elements: [
            {
              tag: 'markdown',
              content: content.substring(0, 5000) // 飞书卡片有长度限制
            }
          ]
        }
      };

      return await this.sendWebhook(webhook, message);
    } catch (error) {
      console.error('❌ 飞书通知失败:', error.message);
      return false;
    }
  },

  /**
   * 发送企业微信消息
   */
  async sendWecom({ webhook, title, content }) {
    if (!webhook) {
      console.log('⚠️ 企业微信Webhook未配置');
      return false;
    }

    try {
      const message = {
        msgtype: 'text',
        text: {
          content: `${title}\n\n${content.substring(0, 4000)}`
        }
      };

      return await this.sendWebhook(webhook, message);
    } catch (error) {
      console.error('❌ 企业微信通知失败:', error.message);
      return false;
    }
  },

  /**
   * 发送邮件通知
   */
  async sendEmail({ smtp, to, subject, body }) {
    if (!smtp || !to) {
      console.log('⚠️ 邮件配置不完整');
      return false;
    }

    // 注意：实际生产环境需要使用 nodemailer 等库
    // 这里仅作示例
    console.log(`📧 邮件通知: ${subject} -> ${to}`);
    console.log(`内容: ${body.substring(0, 200)}...`);
    
    return true;
  },

  /**
   * 发送Slack通知
   */
  async sendSlack({ webhook, title, content, channel }) {
    if (!webhook) {
      console.log('⚠️ SlackWebhook未配置');
      return false;
    }

    try {
      const message = {
        text: title,
        blocks: [
          {
            type: 'header',
            text: {
              type: 'plain_text',
              text: title,
              emoji: true
            }
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: `\`\`\`${content.substring(0, 3000)}\`\`\``
            }
          }
        ]
      };

      if (channel) {
        message.channel = channel;
      }

      return await this.sendWebhook(webhook, message);
    } catch (error) {
      console.error('❌ Slack通知失败:', error.message);
      return false;
    }
  },

  /**
   * 通用Webhook发送
   */
  sendWebhook(url, data) {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url);
      const isHttps = urlObj.protocol === 'https:';
      const client = isHttps ? https : http;

      const postData = JSON.stringify(data);

      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port || (isHttps ? 443 : 80),
        path: urlObj.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        },
        timeout: 10000
      };

      const req = client.request(options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log('✅ Webhook通知发送成功');
            resolve(true);
          } else {
            console.error(`❌ Webhook响应错误: ${res.statusCode}`);
            reject(new Error(`HTTP ${res.statusCode}`));
          }
        });
      });

      req.on('error', (error) => {
        console.error('❌ Webhook请求失败:', error.message);
        reject(error);
      });

      req.on('timeout', () => {
        req.destroy();
        reject(new Error('请求超时'));
      });

      req.write(postData);
      req.end();
    });
  },

  /**
   * 发送钉钉通知
   */
  async sendDingtalk({ webhook, title, content }) {
    if (!webhook) {
      console.log('⚠️ 钉钉Webhook未配置');
      return false;
    }

    try {
      const message = {
        msgtype: 'markdown',
        markdown: {
          title: title,
          text: `## ${title}\n\n${content.substring(0, 4000)}`
        }
      };

      return await this.sendWebhook(webhook, message);
    } catch (error) {
      console.error('❌ 钉钉通知失败:', error.message);
      return false;
    }
  }
};

module.exports = notifier;
