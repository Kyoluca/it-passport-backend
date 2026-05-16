require 'net/http'
require 'uri'
require 'json'
require 'base64'

# 1. 填入你的 API Key
API_KEY = "AIzaSyDRC1XfMQU_5XlyCmctObQCYkpqP3afyjs"

# 💡 V3.1 升级：换用 2026 年度旗舰模型 3.1-pro-preview，确保长文本 JSON 逻辑严密、不丢字段
uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=#{API_KEY}")

qs_pdf_path = "data/pdfs/2026r08_ip_qs.pdf"
ans_pdf_path = "data/pdfs/2026r08_ip_ans.pdf" # 确保本地有这个官方答案 PDF，没有的话可以用之前的真题测试

puts "正在加载 真题与答案 PDF 文件（只需加载一次）..."
qs_pdf_base64 = Base64.strict_encode64(File.read(qs_pdf_path))

# 注意：这里需要你有答案文件，如果没有，可以暂时用 qs_pdf_path 占位测试，正式跑请确保有答案PDF
ans_pdf_base64 = File.exist?(ans_pdf_path) ? Base64.strict_encode64(File.read(ans_pdf_path)) : qs_pdf_base64

all_results = []
# 💡 V3.1 升级：降低批处理大小，每次 5 题，确保 AI 保持最高注意力
batch_size = 5    
total_batches = 20 # 跑 20 轮就是 100 题

(0...total_batches).each do |batch_index|
  start_q = batch_index * batch_size + 1
  end_q = start_q + batch_size - 1

  puts "\n============================================="
  puts "🚀 旗舰模型处理中: 【問#{start_q}】 到 【問#{end_q}】"
  puts "============================================="

  # 终极版 Prompt
  prompt = <<-PROMPT
你是一位严谨客观的日本 IT 行业资深讲师。
附件提供了两份 PDF：第一份是【真题】，第二份是【官方标准答案】。
你的任务是提取出【問#{start_q}】到【問#{end_q}】的内容，并为每一题生成极其专业、准确的中文真题解析。

🚨 工作流程极其重要：
1. 你必须首先在【官方标准答案】PDF 中查找到该题的正确选项。
2. 基于官方的正确选项，反推并撰写解析。绝对不能出现你算出的答案与官方答案不一致的情况！

🚨 组合题特殊规则：
如果遇到组合题（如选项是ア:a,b イ:a,c...，且题目包含 a, b, c 的陈述），请在 `options_analysis` 中直接分别解析 a, b, c 陈述的对错即可，不需要解析ア/イ/ウ/エ。前端会自动渲染陈述内容。

Output 要求（严格输出纯 JSON 数组，不要包含 ```json 等 markdown 符号）：
[
  {
    "question_number": #{start_q},
    "correct_answer": "提取出的官方正确选项（如：ア）",
    "question_type": "概念题 或 計算题",
    "detailed_explanation": "这是本服务的核心价值！请进行体系化的知识点归纳。排版要求：使用【】来划分模块，使用换行符号 \\n 和项目符号来罗列要点。\\n如果是概念题：请详细对比核心概念。\\n如果是計算题：请参照以下格式给出分步推导过程：\\n【前提条件】...\\n【推导步骤】...\\n【最终结论】因此官方答案为X。",
    "options_analysis": [
      // 🚨 严厉警告：绝对不能省略任何一个选项的 translation 字段！必须逐一翻译！
      // 注意：如果是 "計算题"，此数组必须留空 []。
      {
        "original_text": "选项的日文原文",
        "translation": "选项的精准中文翻译",
        "explanation": "明确判定该选项对/错，并解释原因。"
      }
    ],
    "tip": "一句话备考提示或秒杀口诀。"
  }
]
  PROMPT

  request_body = {
    contents: [
      {
        parts: [
          { text: prompt },
          { inline_data: { mime_type: "application/pdf", data: qs_pdf_base64 } },
          { inline_data: { mime_type: "application/pdf", data: ans_pdf_base64 } }
        ]
      }
    ]
  }

  max_retries = 3
  retries = 0
  success = false

  while retries < max_retries && !success
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 180 
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = request_body.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        generated_text = result.dig("candidates", 0, "content", "parts", 0, "text")

        clean_json = generated_text.gsub(/```json\n?/i, "").gsub(/```/i, "").strip
        parsed_json = JSON.parse(clean_json)
        
        filename = "q#{start_q}_to_q#{end_q}.json"
        File.write(filename, clean_json)
        puts "✅ 成功！已保存到 #{filename}"
        
        all_results.concat(parsed_json)
        success = true
        
        puts "⏳ 休息 10 秒后继续..."
        sleep(10)
        
      elsif response.code == "503" || response.code == "429"
        retries += 1
        puts "⚠️ 遇到服务器拥堵 (#{response.code})，等待 15 秒后进行第 #{retries} 次重试..."
        sleep(15)
      else
        puts "❌ 请求遇到未知错误：#{response.code} #{response.message}"
        puts response.body
        break
      end
      
    rescue JSON::ParserError => e
      retries += 1
      puts "⚠️ AI 输出的 JSON 格式错乱，等待 10 秒后进行第 #{retries} 次重试..."
      sleep(10)
    rescue Net::ReadTimeout => e
      retries += 1
      puts "⚠️ 网络请求超时，等待 10 秒后进行第 #{retries} 次重试..."
      sleep(10)
    rescue => e
      retries += 1
      puts "⚠️ 发生异常: #{e.message}，等待 10 秒后进行第 #{retries} 次重试..."
      sleep(10)
    end
  end
  
  if !success
    puts "🚨 警告：【問#{start_q}】 到 【問#{end_q}】 处理彻底失败，跳过此批次。"
  end
end

# 循环结束后，将所有数据保存为一个终极文件
File.write("data/output/all_100_questions_2026r08.json", JSON.pretty_generate(all_results))
puts "\n🎉🎉🎉 100道题已全部合并保存为 all_100_questions.json！"

# 💡 V3.1 升级：自动清理所有的中间小文件
puts "\n🧹 正在清理中间文件..."
(0...total_batches).each do |batch_index|
  start_q = batch_index * batch_size + 1
  end_q = start_q + batch_size - 1
  filename = "q#{start_q}_to_q#{end_q}.json"
  File.delete(filename) if File.exist?(filename)
end
puts "✨ 清理完成！你的文件夹现在极其清爽。"