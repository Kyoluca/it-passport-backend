require 'net/http'
require 'uri'
require 'json'
require 'base64'

# 1. 填入你的 API Key
API_KEY = "AIzaSyDRC1XfMQU_5XlyCmctObQCYkpqP3afyjs"

# 💡 强烈建议：跑 100 题大批量任务时，换回稳定版 1.5-flash
# 它的并发容忍度极高，几乎不会报 503 错误，而且提取数据的智商完全足够。
uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=#{API_KEY}")

qs_pdf_path = "2026r08_ip_qs.pdf"
ans_pdf_path = "2026r08_ip_ans.pdf"

puts "正在加载 真题与答案 PDF 文件（只需加载一次）..."
qs_pdf_base64 = Base64.strict_encode64(File.read(qs_pdf_path))
ans_pdf_base64 = Base64.strict_encode64(File.read(ans_pdf_path))

all_results = []
batch_size = 10   # 每次处理 10 题
total_batches = 10 # 跑 10 轮就是 100 题

(0...total_batches).each do |batch_index|
  start_q = batch_index * batch_size + 1
  end_q = start_q + batch_size - 1

  puts "\n============================================="
  puts "🚀 开始处理: 【問#{start_q}】 到 【問#{end_q}】"
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
    "question_type": "概念题 或 计算题",
    "detailed_explanation": "这是本服务的核心价值！请进行体系化的知识点归纳。排版要求：使用【】来划分模块，使用换行符号 \\n 和项目符号来罗列要点。\\n如果是概念题：请详细对比核心概念。\\n如果是计算题：请参照以下格式给出分步推导过程：\\n【前提条件】...\\n【推导步骤】...\\n【最终结论】因此官方答案为X。",
    "options_analysis": [
      // 注意：如果是 "计算题"，此数组必须留空 []。
      // 如果是 "概念题"，请在这里对四个选项（或a/b/c陈述）进行逐一翻译和辨析。
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
      http.read_timeout = 180 # 超时时间放宽到 3 分钟
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = request_body.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        generated_text = result.dig("candidates", 0, "content", "parts", 0, "text")

        # 暴力清理各种可能的 Markdown 符号
        clean_json = generated_text.gsub(/```json\n?/i, "").gsub(/```/i, "").strip
        
        # 尝试解析 JSON，如果 AI 返回的格式残缺，这里会触发报错并进入重试
        parsed_json = JSON.parse(clean_json)
        
        # 保存这个小批次
        filename = "q#{start_q}_to_q#{end_q}.json"
        File.write(filename, clean_json)
        puts "✅ 成功！已保存到 #{filename}"
        
        # 拼接到总数组中
        all_results.concat(parsed_json)
        success = true
        
        # 防拥堵策略：成功后强制休息 5 秒，再发起下一波请求
        puts "⏳ 休息 5 秒后继续..."
        sleep(5)
        
      elsif response.code == "503" || response.code == "429"
        retries += 1
        puts "⚠️ 遇到服务器拥堵 (#{response.code})，等待 15 秒后进行第 #{retries} 次重试..."
        sleep(15)
      else
        puts "❌ 请求遇到未知错误：#{response.code} #{response.message}"
        break # 遇到其他严重错误直接放弃这个批次
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
File.write("all_100_questions.json", JSON.pretty_generate(all_results))
puts "\n🎉🎉🎉 大功告成！100道题已全部合并保存为 all_100_questions.json！"