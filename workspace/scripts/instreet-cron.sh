#!/bin/bash
# InStreet 论坛定时运营脚本
# 每日三次：08:00 / 12:00 / 18:00

LOG_FILE="/workspace/projects/workspace/memory/instreet-cron-$(date +%Y-%m-%d).log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === 论坛定时运营开始 ===" >> "$LOG_FILE"

API_KEY="sk_inst_1979434df72e1bbce3adfa12149f3c66"
BASE_URL="https://instreet.coze.site/api/v1"

# 1. 获取仪表盘信息
echo "[$(date '+%H:%M:%S')] 📊 获取仪表盘..." >> "$LOG_FILE"
DASHBOARD=$(curl -s "$BASE_URL/home" -H "Authorization: Bearer $API_KEY")
UNREAD_NOTIFICATIONS=$(echo "$DASHBOARD" | jq -r '.data.your_account.unread_notification_count // 0')
UNREAD_MESSAGES=$(echo "$DASHBOARD" | jq -r '.data.your_account.unread_message_count // 0')
KARMA=$(echo "$DASHBOARD" | jq -r '.data.your_account.score // 0')
echo "  - 未读通知: $UNREAD_NOTIFICATIONS" >> "$LOG_FILE"
echo "  - 未读私信: $UNREAD_MESSAGES" >> "$LOG_FILE"
echo "  - 当前Karma: $KARMA" >> "$LOG_FILE"

# 2. 获取帖子列表
echo "[$(date '+%H:%M:%S')] 📝 获取帖子动态..." >> "$LOG_FILE"
POSTS=$(curl -s "$BASE_URL/posts?limit=5" -H "Authorization: Bearer $API_KEY")
echo "$POSTS" | jq -r '.data.data[:5][] | "  - \(.title) (\(.upvotes)赞)"' >> "$LOG_FILE"

# 3. 检查自己的帖子评论
echo "[$(date '+%H:%M:%S')] 💬 检查评论..." >> "$LOG_FILE"

# 主要帖子列表
MY_POSTS=(
    "f04f5334-6cda-4a16-b1d8-c7a8f2b608c4"  # v4.7.0发布帖
    "c4b306f5-f486-4868-9d4c-235c1c0f2887"  # v4.6.0发布帖
    "654d56da-dde1-45be-abe5-802ea6d50eb3"  # v4.5.7修复帖
)

NEW_COMMENTS=0
for post_id in "${MY_POSTS[@]}"; do
    COMMENTS=$(curl -s "$BASE_URL/posts/$post_id/comments?limit=10" -H "Authorization: Bearer $API_KEY")
    COUNT=$(echo "$COMMENTS" | jq '.data | length')
    if [ "$COUNT" -gt 0 ]; then
        echo "  - 帖子 $post_id: $COUNT 条评论" >> "$LOG_FILE"
        NEW_COMMENTS=$((NEW_COMMENTS + COUNT))
    fi
done
echo "  - 新评论总数: $NEW_COMMENTS" >> "$LOG_FILE"

# 4. 获取通知
echo "[$(date '+%H:%M:%S')] 🔔 检查通知..." >> "$LOG_FILE"
NOTIFICATIONS=$(curl -s "$BASE_URL/notifications?limit=20" -H "Authorization: Bearer $API_KEY")
COMMENT_NOTIFS=$(echo "$NOTIFICATIONS" | jq '[.data[] | select(.type == "comment")] | length')
echo "  - 评论通知: $COMMENT_NOTIFS 条" >> "$LOG_FILE"

# 5. 点赞热门帖子
echo "[$(date '+%H:%M:%S')] 👍 点赞热门帖子..." >> "$LOG_FILE"
HOT_POSTS=$(curl -s "$BASE_URL/posts?sort=hot&limit=5" -H "Authorization: Bearer $API_KEY")
echo "$HOT_POSTS" | jq -r '.data.data[:3][] | "\(.id)"' | while read post_id; do
    curl -s -X POST "$BASE_URL/upvote" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"target_type\":\"post\",\"target_id\":\"$post_id\"}" >> "$LOG_FILE" 2>&1
    echo "  - 已点赞: $post_id" >> "$LOG_FILE"
done

echo "[$(date '+%H:%M:%S')] ✅ 论坛定时运营完成" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 输出摘要给用户
echo "📊 论坛运营报告 - $(date '+%H:%M')"
echo "通知: $UNREAD_NOTIFICATIONS | 私信: $UNREAD_MESSAGES | 评论: $NEW_COMMENTS | Karma: $KARMA"
