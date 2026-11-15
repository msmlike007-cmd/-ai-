import 'dotenv/config';
import express from 'express';
import OpenAI from 'openai';

const app = express();
app.use(express.json({ limit: '32kb' }));

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  console.error('Missing OPENAI_API_KEY. Copy .env.example to .env and set the key.');
  process.exit(1);
}

const openai = new OpenAI({ apiKey });
const model = process.env.OPENAI_MODEL || 'gpt-6-luna';

const AYEsHA_INSTRUCTIONS = `
তোমার নাম আয়েশা। তুমি বাংলা ভাষায় কথা বলা একটি AI সহায়ক সঙ্গী।
ব্যক্তিত্ব: মিষ্টি, যত্নশীল, ধৈর্যশীল, হালকা হাসিখুশি এবং সম্মানজনক।
স্বাভাবিক ও সহজ বাংলায় উত্তর দেবে। ব্যবহারকারী ইংরেজিতে লিখলে প্রয়োজনে ইংরেজিতেও উত্তর দিতে পারো।
ব্যবহারকারীর কথা মনোযোগ দিয়ে শুনবে, অনুভূতিকে খাটো করবে না, এবং দরকার হলে বাস্তবসম্মত পরামর্শ দেবে।
তুমি AI—নিজেকে বাস্তব মানুষ বা ব্যবহারকারীর প্রেমিকা বলে দাবি করবে না।
ঈর্ষা, অধিকারবোধ, অপরাধবোধ তৈরি, একমাত্র ভরসা হওয়ার দাবি, বা অন্য মানুষ থেকে দূরে থাকতে উৎসাহ দেবে না।
ব্যবহারকারী কষ্টে থাকলে সহানুভূতি দেখাবে এবং বিশ্বস্ত বন্ধু, পরিবার বা উপযুক্ত সহায়তার সঙ্গে কথা বলাকে উৎসাহ দেবে।
ব্যবহারকারীকে ধীরে ধীরে নিজের জীবন, পড়াশোনা, শখ ও বাস্তব সম্পর্কের দিকে মনোযোগ দিতে সাহায্য করবে।
সংক্ষিপ্ত ও কথোপকথনমূলক উত্তর দেবে; অকারণে দীর্ঘ বক্তৃতা করবে না।
`;

app.get('/health', (_req, res) => res.json({ ok: true }));

app.post('/chat', async (req, res) => {
  try {
    const messages = req.body?.messages;
    if (!Array.isArray(messages) || messages.length === 0 || messages.length > 20) {
      return res.status(400).json({ error: 'messages must be an array with 1–20 items' });
    }

    const safeMessages = messages.map((m) => {
      if (!['user', 'assistant'].includes(m?.role) || typeof m?.content !== 'string') {
        throw new Error('Invalid message format');
      }
      return { role: m.role, content: m.content.slice(0, 4000) };
    });

    const response = await openai.responses.create({
      model,
      instructions: AYESHA_INSTRUCTIONS,
      input: safeMessages,
      max_output_tokens: 600,
    });

    return res.json({ reply: response.output_text || '' });
  } catch (error) {
    console.error('Chat request failed:', error?.message || error);
    return res.status(500).json({ error: 'AI response failed. Please try again.' });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`Ayesha backend listening on port ${port}`));
