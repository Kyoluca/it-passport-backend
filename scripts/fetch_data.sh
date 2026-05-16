#!/bin/bash
# fetch_data.sh - IT Passport 官方真题与答案批量自动化下载脚本

# 1. 定义存放 PDF 的目标专属文件夹
DATA_DIR="data/pdfs"

# 2. 自动检查并创建文件夹（如果不存在的话）
if [ ! -dir "$DATA_DIR" ]; then
    echo "📂 目标文件夹不存在，正在为你创建: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# 3. 定义需要批量下载的考试期数数组
# 2023r05 代表令和5年公开题（目前拿来做MVP测试）
# 未来如果你想顺便把别的年份也下了，直接在后面空格追加即可，例如: ("2023r05" "2024r06")
EXAMS=("2023r05")

echo "🚀 开始批量下载 IT Passport 官方真题与标准答案..."

for exam in "${EXAMS[@]}"; do
    echo "--------------------------------------------------"
    echo "⏳ 正在抓取 [${exam}] 年度数据..."
    
    # 下载官方真题 PDF
    QS_URL="https://www3.jitec.ipa.go.jp/JitesCbt/html/openinfo/pdf/questions/${exam}_ip_qs.pdf"
    echo "📥 抓取真题: ${exam}_ip_qs.pdf"
    wget -P "$DATA_DIR" "$QS_URL"
    
    # 下载官方标准答案 PDF
    ANS_URL="https://www3.jitec.ipa.go.jp/JitesCbt/html/openinfo/pdf/questions/${exam}_ip_ans.pdf"
    echo "📥 抓取答案: ${exam}_ip_ans.pdf"
    wget -P "$DATA_DIR" "$ANS_URL"
    
done

echo "--------------------------------------------------"
echo "✅ 批量下载任务圆满完成！"
echo "📂 所有 PDF 文件已整齐存入: $DATA_DIR"