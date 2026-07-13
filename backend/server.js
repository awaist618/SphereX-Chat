const express = require('express');
const { Resend } = require('resend'); // 1. Use Resend instead of Nodemailer
const cors = require('cors');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const resend = new Resend(process.env.RESEND_API_KEY); // 2. Initialize Resend

// SECURITY: Rate Limiter (Prevent Brute Force)
const signupLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Too many accounts created from this IP. Try again in an hour.' }
});

const verifyLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 3,
  message: { error: 'Too many wrong attempts. Try again in 10 minutes.' }
});

app.use(cors());
app.use(bodyParser.json());

const otpStore = new Map();

// ROUTE: REQUEST OTP
app.post('/api/auth/signup', signupLimiter, async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });

    const otp = crypto.randomInt(100000, 999999).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000;
    otpStore.set(email, { otp, expiresAt, attempts: 0 });

    // 3. SECURE SEND: Send using Resend's Official API
    const { data, error } = await resend.emails.send({
      from: 'SphereX Official <onboarding@resend.dev>', // 100% Hidden Gmail
      to: [email],
      subject: 'Verification Code',
      html: `
        <div style="font-family: sans-serif; padding: 20px; background: #0b1020; color: white; border-radius: 10px; border: 1px solid #7C4DFF;">
          <h2 style="color: #7C4DFF; margin-top: 0;">SphereX Secure</h2>
          <p>Your 6-digit verification code is:</p>
          <h1 style="letter-spacing: 5px; font-size: 32px; color: #FFFFFF;">${otp}</h1>
          <p style="color: #AAAAAA;">This code will expire in 5 minutes. Do not share this code with anyone.</p>
          <hr style="border: 0; border-top: 1px solid #333; margin: 20px 0;">
          <small style="color: #666;">If you didn't request this code, you can safely ignore this email.</small>
        </div>
      `
    });

    if (error) {
      console.error('Resend Error:', error);
      return res.status(500).json({ error: 'Failed to send secure email' });
    }

    res.status(200).json({ message: 'OTP sent' });

  } catch (error) {
    console.error('Signup Error:', error);
    res.status(500).json({ error: 'Internal Security Error' });
  }
});

// ROUTE: VERIFY OTP
app.post('/api/auth/verify', verifyLimiter, (req, res) => {
  const { email, otp } = req.body;
  const record = otpStore.get(email);

  if (!record) return res.status(400).json({ error: 'Invalid request' });

  record.attempts++;
  if (record.attempts > 3) {
    otpStore.delete(email);
    return res.status(400).json({ error: 'Max attempts exceeded. Request a new code.' });
  }

  if (Date.now() > record.expiresAt) {
    otpStore.delete(email);
    return res.status(400).json({ error: 'Code expired' });
  }

  if (crypto.timingSafeEqual(Buffer.from(record.otp), Buffer.from(otp))) {
    otpStore.delete(email);
    res.status(200).json({
      message: 'Verified',
      token: crypto.randomBytes(32).toString('hex')
    });
  } else {
    res.status(400).json({ error: 'Invalid code' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Professional Shielded Backend live on port ${PORT}`));
