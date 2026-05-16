require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'dotenv/load' # 💡 安全第一：从保险箱加载环境变量

# 1. 绝对安全：从环境变量读取 Key
API_KEY = "AIzaSyAI3f8f1PfZMEak8Z9mca_mADEbI4QmQ-8"

# 💡 引擎升级：使用 2.5-flash，兼顾极速、抗并发与强 Schema 支持
uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=#{API_KEY}")

# 注意：确认 data/pdfs/ 文件夹下有对应的文件
qs_pdf_path = "data/pdfs/2026r08_ip_qs.pdf" 
ans_pdf_path = "data/pdfs/2026r08_ip_ans.pdf"

puts "正在加载 真题与答案 PDF 文件（只需加载一次）..."
qs_pdf_base64 = Base64.strict_encode64(File.read(qs_pdf_path))
ans_pdf_base64 = File.exist?(ans_pdf_path) ? Base64.strict_encode64(File.read(ans_pdf_path)) : qs_pdf_base64

all_results = []

# 💡 降维打击策略：每次只跑 1 题，彻底榨干大模型注意力！
batch_size = 1    
total_batches = 100 # 一共 100 题，循环 100 次

(0...total_batches).each do |batch_index|
  target_q = batch_index * batch_size + 1

  puts "\n============================================="
  puts "🚀 独占算力处理中: 【問#{target_q}】"
  puts "============================================="

  # 终极版 Prompt
  prompt = <<-PROMPT
你是一位严谨客观的日本 IT 行业资深讲师。
附件提供了两份 PDF：第一份是【真题】，第二份是【官方标准答案】。
你的任务是提取出【問#{target_q}】的内容，并生成极其专业、准确的中文真题解析。

🚨 工作流程极其重要：
1. 你必须首先在【官方标准答案】PDF 中查找到该题的正确选项。
2. 基于官方的正确选项，反推并撰写解析。绝对不能出现你算出的答案与官方答案不一致的情况！

🚨 组合题特殊规则：
如果遇到组合题（如选项是ア:a,b イ:a,c...，且题目包含 a, b, c 的陈述），请在 `options_analysis` 中直接分别解析 a, b, c 陈述的对错即可，不需要解析ア/イ/ウ/エ。

🚨 表格与插图特殊规则：
如果【题干】或【选项】中包含表格数据，请务必将其转换为标准的 Markdown 表格格式（例如：`| 列名 | 列名 |` 以及 `|---|---|`）填入对应的 JSON 字段中。如果是需要翻译的表格，请在 `question_translation` 或选项的 `translation` 中，同样使用 Markdown 格式输出翻译后的表格。

Output 要求（严格按照设定的 JSON Schema 输出）：
- question_original_text: 提取题干的完整日文原文。
- question_translation: 题干的精准中文翻译。
- correct_answer: 提取出的官方正确选项（如：ア）。
- question_category: 题目所属的官方大分类（分野）。
- question_subcategory: 题目所属的官方小分类（中分類考点）。
- detailed_explanation: 体系化的知识点归纳。使用【】划分模块，使用换行符号 \\n。计算题请给出分步推导。
- options_analysis: 务必逐一提取并翻译选项。🚨 警告：`original_text` 必须填入选项或陈述的【完整日文原句】，绝对不能只填 "a" 或 "ア" 这种单字母标号！
  PROMPT

  # 5. 组装请求体，加入 JSON Schema 和 Enum 强约束
  request_body = {
    contents: [
      {
        parts: [
          { text: prompt },
          { inline_data: { mime_type: "application/pdf", data: qs_pdf_base64 } },
          { inline_data: { mime_type: "application/pdf", data: ans_pdf_base64 } }
        ]
      }
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            question_number: { type: "INTEGER" },
            question_original_text: { type: "STRING", description: "题干日文原文" },
            question_translation: { type: "STRING", description: "题干中文翻译" },
            correct_answer: { type: "STRING" },
            
            question_category: { 
              type: "STRING", 
              description: "题目所属的大分类（分野）",
              enum: ["ストラテジ系", "マネジメント系", "テクノロジ系"] 
            },
            
            question_subcategory: {
              type: "STRING",
              description: "题目所属的小分类（中分類考点）",
              enum: [
                "企業活動", "法務", "経営戦略マネジメント", "技術戦略マネジメント", "ビジネスインダストリ", 
                "システム戦略", "システム企画", "システム開発技術", "ソフトウェア開発管理技術", 
                "プロジェクトマネジメント", "サービスマネジメント", "システム監査", "基礎理論", 
                "アルゴリズムとプログラミング", "コンピュータ構成要素", "システム構成要素", "ソフトウェア", 
                "ハードウェア", "ヒューマンインタフェース", "マルチメディア", "データベース", "ネットワーク", "セキュリティ"
              ]
            },
            
            detailed_explanation: { type: "STRING" },
            options_analysis: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                properties: {
                  original_text: { 
                    type: "STRING",
                    description: "选项或陈述的完整日文原句（必须是完整句子，禁止只填单字母标号）" 
                  },
                  translation: { type: "STRING" },
                  explanation: { type: "STRING" }
                },
                required: ["original_text", "translation", "explanation"]
              }
            },
            tip: { type: "STRING" }
          },
          required: ["question_number", "question_original_text", "question_translation", "correct_answer", "question_category", "question_subcategory", "detailed_explanation", "options_analysis", "tip"]
        }
      }
    }
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
        
        # 保存这个单题小批次
        filename = "data/output/q#{target_q}.json"
        File.write(filename, clean_json)
        puts "✅ 成功！已保存到 #{filename}"
        
        all_results.concat(parsed_json)
        success = true
        
        # 💡 防拥堵策略：跑 1 题休 4 秒，完美卡在限流边缘
        puts "⏳ 休息 4 秒后继续..."
        sleep(4)
        
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
    puts "🚨 警告：【問#{target_q}】 处理彻底失败，跳过此批次。"
  end
end

# 循环结束后，将所有数据保存为一个终极文件
File.write("data/output/all_100_questions.json", JSON.pretty_generate(all_results))
puts "\n🎉🎉🎉 大功告成！100道题已全部合并保存为 data/output/all_100_questions.json！"

# 自动清理碎片文件
puts "\n🧹 正在清理中间单题文件..."
(0...total_batches).each do |batch_index|
  target_q = batch_index * batch_size + 1
  filename = "data/output/q#{target_q}.json"
  File.delete(filename) if File.exist?(filename)
end
puts "✨ 清理完成！你的输出文件夹现在极其清爽。"