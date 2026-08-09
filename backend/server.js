const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { OAuth2Client } = require('google-auth-library'); // Add Google Auth
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use('/uploads', express.static('uploads'));

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = './uploads/';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});
const upload = multer({ storage });

// SOCKET.IO CONNECTION
const connectedUsers = new Map(); // username -> socketId

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('join', async (username) => {
    connectedUsers.set(username, socket.id);
    await User.findOneAndUpdate({ username }, { isOnline: true });
    io.emit('status_change', { username, isOnline: true });
    console.log(`${username} joined with socket ${socket.id}`);
  });

  socket.on('disconnect', async () => {
    for (const [username, id] of connectedUsers.entries()) {
      if (id === socket.id) {
        connectedUsers.delete(username);
        await User.findOneAndUpdate({ username }, { isOnline: false });
        io.emit('status_change', { username, isOnline: false });
        break;
      }
    }
    console.log('User disconnected:', socket.id);
  });
});
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'hafsaah2222@gmail.com',
    pass: process.env.EMAIL_PASS
  }
});
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// DATABASE CONNECTION
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('Connected to SphereX Secure Database'))
  .catch(err => console.error('Database Connection Error:', err));

// SCHEMAS
const userSchema = new mongoose.Schema({
  username: { type: String, unique: true, required: true },
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true }, // Hashed password
  about: { type: String, default: "Available" },
  phone: { type: String, default: "Not linked" },
  profilePic: { type: String, default: null },
  isOnline: { type: Boolean, default: false },
  joinedAt: { type: Date, default: Date.now }
});

const contactRequestSchema = new mongoose.Schema({
  sender: { type: String, required: true },
  receiver: { type: String, required: true },
  status: { type: String, enum: ['pending', 'accepted', 'declined'], default: 'pending' },
  timestamp: { type: Date, default: Date.now }
});

const contactSchema = new mongoose.Schema({
  user: { type: String, required: true },
  contact: { type: String, required: true },
  timestamp: { type: Date, default: Date.now }
});

const conversationSchema = new mongoose.Schema({
  id: { type: String, unique: true, required: true },
  participants: [{ type: String, required: true }],
  lastMessage: { type: String, default: "" },
  updatedAt: { type: Date, default: Date.now }
});

const messageSchema = new mongoose.Schema({
  conversationId: { type: String, required: true },
  sender: { type: String, required: true },
  receiver: { type: String, required: true },
  text: { type: String },
  mediaUrl: { type: String },
  type: { type: String, default: 'text' }, // 'text', 'image', 'video'
  timestamp: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);
const ContactRequest = mongoose.model('ContactRequest', contactRequestSchema);
const Contact = mongoose.model('Contact', contactSchema);
const Conversation = mongoose.model('Conversation', conversationSchema);
const Message = mongoose.model('Message', messageSchema);
const Otp = mongoose.model('Otp', otpSchema);

// SECURITY: Rate Limiters
const signupLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Security Alert: Too many signup attempts.' }
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many login attempts. Please wait 15 minutes.' }
});

app.use(cors());
app.use(bodyParser.json());

// ROUTE: REQUEST OTP (SIGNUP)
app.post('/api/auth/signup', signupLimiter, async (req, res) => {
  try {
    const { email, username, password } = req.body;
    if (!email || !username || !password) return res.status(400).json({ error: 'All fields required' });

    // SECURITY: Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { username: username.toLowerCase() }]
    });

    if (existingUser) {
      return res.status(400).json({ error: 'User or Email already exists' });
    }

    // Hash password BEFORE saving to temporary OTP store
    const hashedPassword = await bcrypt.hash(password, 12);

    const otpCode = crypto.randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await Otp.findOneAndUpdate(
      { email: email.toLowerCase() },
      { otp: otpCode, expiresAt, attempts: 0, username: username, password: hashedPassword },
      { upsert: true, new: true }
    );

    const mailOptions = {
      from: `"SphereX Official" <${process.env.EMAIL_USER || 'hafsaah2222@gmail.com'}>`,
      to: email,
      subject: 'SphereX Verification Code',
      html: `<div style="background:#0b1020;color:white;padding:30px;border-radius:15px;border:2px solid #7C4DFF;font-family:sans-serif;text-align:center;">
              <h1 style="color:#7C4DFF;">SphereX</h1>
              <p style="font-size:18px;">Your verification code is:</p>
              <div style="background:#161b33;padding:20px;border-radius:10px;display:inline-block;margin:20px 0;">
                <span style="font-size:32px;font-weight:bold;letter-spacing:5px;color:white;">${otpCode}</span>
              </div>
              <p style="color:#white70;font-size:14px;">This code will expire in 5 minutes.</p>
              <p style="color:#FF4C61;font-size:12px;margin-top:20px;">Security Alert: If you did not request this code, please ignore this email.</p>
             </div>`
    };

    await transporter.sendMail(mailOptions);
    res.status(200).json({ message: 'OTP sent' });

  } catch (error) {
    res.status(500).json({ error: 'Internal Security Error' });
  }
});

// ROUTE: VERIFY OTP & CREATE USER
app.post('/api/auth/verify', async (req, res) => {
  try {
    const { email, otp } = req.body;
    const record = await Otp.findOne({ email: email.toLowerCase() });

    if (!record) return res.status(400).json({ error: 'Session expired' });

    if (new Date() > record.expiresAt) {
      await Otp.deleteOne({ email: email.toLowerCase() });
      return res.status(400).json({ error: 'Code expired' });
    }

    if (crypto.timingSafeEqual(Buffer.from(record.otp), Buffer.from(otp))) {
      // Move data to permanent User store
      const newUser = new User({
        username: record.username,
        email: email.toLowerCase(),
        password: record.password // Already hashed
      });
      await newUser.save();
      await Otp.deleteOne({ email: email.toLowerCase() });

      res.status(200).json({
        message: 'Verified',
        token: crypto.randomBytes(32).toString('hex'),
        username: record.username
      });
    } else {
      res.status(400).json({ error: 'Invalid code' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Database Verification Error' });
  }
});

// ROUTE: SECURE LOGIN
app.post('/api/auth/login', loginLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Compare provided password with hashed password in DB
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    res.status(200).json({
      message: 'Logged in successfully',
      username: user.username,
      token: crypto.randomBytes(32).toString('hex')
    });
  } catch (error) {
    res.status(500).json({ error: 'Login failure' });
  }
});

// ROUTE: GOOGLE LOGIN
app.post('/api/auth/google', async (req, res) => {
  try {
    const { idToken } = req.body;
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const { email, name, sub: googleId } = payload;

    let user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      // Create new user if not exists
      // Generate a unique username based on name
      let username = name.replace(/\s+/g, '').toLowerCase() + crypto.randomInt(100, 999);

      user = new User({
        username: username,
        email: email.toLowerCase(),
        password: crypto.randomBytes(16).toString('hex'), // Dummy password for social login
      });
      await user.save();
    }

    res.status(200).json({
      message: 'Google Login Success',
      username: user.username,
      token: crypto.randomBytes(32).toString('hex')
    });

  } catch (error) {
    console.error('Google Auth Error:', error);
    res.status(401).json({ error: 'Invalid Google Token' });
  }
});

// ROUTE: SEARCH USER
app.get('/api/users/search', async (req, res) => {
  try {
    const { query, current_user } = req.query;
    if (!query) return res.status(400).json({ error: 'Search required' });
    let searchName = query.startsWith('@') ? query.substring(1).toLowerCase() : query.toLowerCase();

    const users = await User.find({
      username: { $regex: new RegExp('^' + searchName, 'i') },
      username: { $ne: current_user }
    }).limit(10).select('username about profilePic isOnline -_id');

    const results = await Promise.all(users.map(async (u) => {
      const user = u.toObject();

      // Check relationship
      const isContact = await Contact.findOne({ user: current_user, contact: user.username });
      const requestSent = await ContactRequest.findOne({ sender: current_user, receiver: user.username, status: 'pending' });
      const requestReceived = await ContactRequest.findOne({ sender: user.username, receiver: current_user, status: 'pending' });

      user.relationship = isContact ? 'contact' : (requestSent ? 'sent' : (requestReceived ? 'received' : 'none'));
      return user;
    }));

    res.status(200).json(results);
  } catch (error) {
    res.status(500).json({ error: 'Search Security Error' });
  }
});

// ROUTE: SEND CONTACT REQUEST
app.post('/api/contacts/request', async (req, res) => {
  try {
    const { sender, receiver } = req.body;

    const existing = await ContactRequest.findOne({ sender, receiver, status: 'pending' });
    if (existing) return res.status(400).json({ error: 'Request already pending' });

    const request = new ContactRequest({ sender, receiver });
    await request.save();

    // Notify receiver
    const receiverSocketId = connectedUsers.get(receiver);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('contact_request', { sender });
    }

    res.status(200).json({ message: 'Request sent' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to send request' });
  }
});

// ROUTE: GET CONTACT REQUESTS
app.get('/api/contacts/requests/:username', async (req, res) => {
  try {
    const requests = await ContactRequest.find({ receiver: req.params.username, status: 'pending' });
    res.status(200).json(requests);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
});

// ROUTE: RESPOND TO CONTACT REQUEST
app.post('/api/contacts/respond', async (req, res) => {
  try {
    const { sender, receiver, action } = req.body; // action: 'accept' or 'decline'

    if (action === 'accept') {
      await ContactRequest.findOneAndUpdate({ sender, receiver }, { status: 'accepted' });

      // Create mutual contacts
      await Contact.findOneAndUpdate({ user: sender, contact: receiver }, {}, { upsert: true });
      await Contact.findOneAndUpdate({ user: receiver, contact: sender }, {}, { upsert: true });

      // Notify sender
      const senderSocketId = connectedUsers.get(sender);
      if (senderSocketId) {
        io.to(senderSocketId).emit('request_accepted', { receiver });
      }
    } else {
      await ContactRequest.findOneAndDelete({ sender, receiver });
    }

    res.status(200).json({ message: 'Response processed' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to process request' });
  }
});

// ROUTE: SEND MESSAGE (Enhanced with Conversation Logic)
app.post('/api/messages/send', upload.single('media'), async (req, res) => {
  try {
    const { sender, receiver, text, type } = req.body;

    // Find or create conversation
    let convId = [sender, receiver].sort().join('_');
    let conversation = await Conversation.findOne({ id: convId });

    if (!conversation) {
      conversation = new Conversation({
        id: convId,
        participants: [sender, receiver],
        lastMessage: text || "Media attachment"
      });
    } else {
      conversation.lastMessage = text || "Media attachment";
      conversation.updatedAt = Date.now();
    }
    await conversation.save();

    let mediaUrl = null;
    if (req.file) {
      mediaUrl = `http://192.168.0.100:3000/uploads/${req.file.filename}`;
    }

    const newMessage = new Message({
      conversationId: convId,
      sender,
      receiver,
      text,
      mediaUrl,
      type: type || 'text'
    });
    await newMessage.save();

    // Emit real-time message to receiver
    const receiverSocketId = connectedUsers.get(receiver);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('new_message', newMessage);
    }

    res.status(200).json(newMessage);
  } catch (error) {
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// ROUTE: GET CONVERSATIONS (Redefined for clean UI)
app.get('/api/conversations/:username', async (req, res) => {
  try {
    const { username } = req.params;
    const conversations = await Conversation.find({
      participants: username
    }).sort({ updatedAt: -1 });

    const results = await Promise.all(conversations.map(async (c) => {
      const conv = c.toObject();
      const otherUser = conv.participants.find(p => p !== username);
      const profile = await User.findOne({ username: otherUser }).select('profilePic isOnline');

      return {
        _id: otherUser,
        lastMessage: conv.lastMessage,
        timestamp: conv.updatedAt,
        profilePic: profile?.profilePic,
        isOnline: profile?.isOnline
      };
    }));

    res.status(200).json(results);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

// ROUTE: GET PROFILE
app.get('/api/users/profile/:username', async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username }).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ROUTE: UPDATE PROFILE
app.put('/api/users/update', async (req, res) => {
  try {
    const { username, about, phone } = req.body;
    const user = await User.findOneAndUpdate(
      { username },
      { about, phone },
      { new: true }
    ).select('-password');
    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// ROUTE: DELETE ACCOUNT
app.delete('/api/users/delete/:username', async (req, res) => {
  try {
    const { username } = req.params;
    await User.deleteOne({ username });
    // Also cleanup messages
    await Message.deleteMany({ $or: [{ sender: username }, { receiver: username }] });
    res.status(200).json({ message: 'Account deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Fortress Backend live on port ${PORT}`));
