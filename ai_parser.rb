require 'net/http'
require 'uri'
require 'json'
require 'base64'

# 1. 配置你的 API Key 和请求 URL
API_KEY = "AIzaSyDRC1XfMQU_5XlyCmctObQCYkpqP3afyjs"
uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=#{API_KEY}")

# 2. 读取 PDF 并进行 Base64 编码
pdf_path = "2023r05_ip_qs.pdf"
puts "正在加载 PDF 文件..."
pdf_base64 = Base64.strict_encode64(File.read(pdf_path))

# 3. 设定系统提示词（融入了你的严谨版解析要求，并加入了中文翻译层）
prompt = <<-PROMPT
你是一位严谨客观的日本 IT 行业资深讲师。
请阅读附件中的 IT Passport 考试真题 PDF 文件。
你的任务是提取出【問1】到【問5】的内容，并为每一题生成极其专业、准确的真题解析。

Output 要求：请严格输出为纯 JSON 数组格式（不要包含 markdown 代码块符号，如 ```json），方便我直接解析。数据结构如下：
[
  {
    "question_number": 1,
    "concept_summary": "知识点归纳。用 2-3 句话直接总结本题考查的核心 IT 概念或法律法规原理。",
    "options_analysis": [
      {
        "original_text": "选项的日文原文",
        "translation": "选项的精准中文翻译",
        "explanation": "明确判定该选项对/错，然后以严谨的逻辑解释原因。"
      }
    ],
    "tip": "备考提示。一句话总结本题的核心考点或易错点。"
  }
]
PROMPT

# 4. 组装请求体 (Payload)
request_body = {
  contents: [
    {
      parts: [
        { text: prompt },
        {
          inline_data: {
            mime_type: "application/pdf",
            data: pdf_base64
          }
        }
      ]
    }
  ]
}

# 5. 发送 HTTP POST 请求
puts "正在向大模型发送请求，请耐心等待（处理 PDF 大约需要 10-20 秒）..."
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
request.body = request_body.to_json

response = http.request(request)

# 6. 处理返回结果
if response.is_a?(Net::HTTPSuccess)
  result = JSON.parse(response.body)
  # 提取模型生成的文本内容
  generated_text = result.dig("candidates", 0, "content", "parts", 0, "text")
  
  # 将结果保存到文件，方便你查看
  File.write("q1_to_q5_output.json", generated_text)
  puts "✅ 成功！前 5 题的 JSON 解析已保存到 q1_to_q5_output.json"
else
  puts "❌ 请求失败：#{response.code} #{response.message}"
  puts response.body
end
