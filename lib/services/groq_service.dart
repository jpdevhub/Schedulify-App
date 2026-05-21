import 'dart:convert';
import 'package:http/http.dart' as http;

const _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama-3.3-70b-versatile';

class GroqService {
  final String apiKey;
  GroqService(this.apiKey);

  Future<List<Map<String, dynamic>>> parseSchedule(String rawText) async {
    const systemPrompt = '''
You are a schedule parser. Parse the raw timetable text and return ONLY a valid JSON array.
Each entry must have these exact fields:
- dayOfWeek: integer (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)
- startTime: string "HH:mm"
- endTime: string "HH:mm"
- courseName: string
- courseCode: string
- facultyName: string
- roomName: string
- studentGroup: string or null
- sessionType: "lecture" | "lab" | "tutorial"
Return ONLY the JSON array, no markdown, no explanation.
''';

    final res = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': rawText},
        ],
        'temperature': 0.1,
        'max_tokens': 4096,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Groq API error: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body);
    final content = body['choices'][0]['message']['content'] as String;
    final cleaned = content.replaceAll(RegExp(r'```json|```'), '').trim();
    return List<Map<String, dynamic>>.from(jsonDecode(cleaned));
  }

  Future<String> detectConflicts(List<Map<String, dynamic>> entries) async {
    final res = await http.post(
      Uri.parse(_groqApiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': 'Analyze timetable entries for room, faculty, or time conflicts. Be concise.',
          },
          {
            'role': 'user',
            'content': jsonEncode(entries),
          },
        ],
        'temperature': 0.2,
        'max_tokens': 512,
      }),
    );

    if (res.statusCode != 200) return 'Could not check conflicts.';
    final body = jsonDecode(res.body);
    return body['choices'][0]['message']['content'] as String;
  }
}
