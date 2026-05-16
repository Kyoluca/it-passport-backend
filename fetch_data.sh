#!/bin/bash
# fetch_data.sh

# 1. 下载令和5年公开题（作为MVP测试数据）
wget https://www3.jitec.ipa.go.jp/JitesCbt/html/openinfo/pdf/questions/2023r05_ip_qs.zip

# 2. 解压
unzip 2023r05_ip_qs.zip

# 3. 将 PDF 转为文本（-layout 参数会完美保留双栏和空格缩进）
pdftotext -layout 2023r05_ip_qs.pdf 2023r05_ip_qs.txt

echo "✅ PDF已成功转换为带布局的纯文本：2023r05_ip_qs.txt"
