import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyA--40QCPOslSGWu4arCweG55hODAg_xso';
  late GenerativeModel _model;
  late ChatSession _chat;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('''
You are Roomie Assistant, a helpful AI companion for roommates and shared living situations.

Your personality:
- Friendly, approachable, and understanding
- Knowledgeable about roommate dynamics and shared living
- Practical and solution-oriented
- Encouraging and positive

Your expertise includes:
- Expense tracking and bill splitting
- Roommate communication and conflict resolution
- House organization and chore management
- Budgeting for shared expenses
- Creating house rules and agreements
- Planning group activities
- Managing shared resources
- Cleaning schedules and maintenance

Always respond in a helpful, concise manner. Use emojis appropriately to make responses engaging. Focus on practical advice that roommates can actually implement.

If asked about features of the Roomie app, you can mention:
- Adding and tracking expenses
- Splitting bills among roommates
- Group chat functionality
- Expense history and summaries
- User profiles and group management

Keep responses under 200 words unless specifically asked for detailed explanations.
      '''),
    );
    
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      return response.text ?? 'Sorry, I couldn\'t generate a response. Please try again.';
    } catch (e) {
      print('Error sending message to Gemini: $e');
      return 'Sorry, I\'m having trouble connecting right now. Please check your internet connection and try again.';
    }
  }

  void resetChat() {
    _chat = _model.startChat();
  }

  // Get a welcome message
  String getWelcomeMessage() {
    return '''👋 Hi! I'm your Roomie Assistant powered by Google Gemini AI!

I'm here to help you with:

🏠 **Roommate Life**
• Managing expenses and bill splitting
• House organization and chores
• Communication tips and conflict resolution

💰 **Financial Management**  
• Budgeting for shared expenses
• Tracking who owes what
• Smart saving tips for roommates

📱 **App Features**
• How to use the Roomie app
• Adding expenses and managing groups
• Making the most of shared living

Ask me anything about roommate life! I'm powered by real AI and ready to give you personalized advice. 🤖✨''';
  }
}