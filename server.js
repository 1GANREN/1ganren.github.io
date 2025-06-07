const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const bodyParser = require('body-parser');
const validator = require('validator');

const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Подключение к MongoDB
mongoose.connect('mongodb://localhost:27017/ganrenhub', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    useCreateIndex: true
})
.then(() => console.log('Connected to MongoDB'))
.catch(err => console.error('MongoDB connection error:', err));

// Модель пользователя
const UserSchema = new mongoose.Schema({
    username: { 
        type: String, 
        required: true, 
        unique: true,
        minlength: 3,
        maxlength: 20,
        trim: true
    },
    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true,
        validate(value) {
            if (!validator.isEmail(value)) {
                throw new Error('Email is invalid');
            }
        }
    },
    password: {
        type: String,
        required: true,
        minlength: 6,
        trim: true
    },
    role: { 
        type: String, 
        default: 'user',
        enum: ['user', 'admin']
    },
    createdAt: { 
        type: Date, 
        default: Date.now 
    },
    lastLogin: Date
});

// Хеширование пароля перед сохранением
UserSchema.pre('save', async function(next) {
    const user = this;
    
    if (user.isModified('password')) {
        user.password = await bcrypt.hash(user.password, 10);
    }
    
    next();
});

const User = mongoose.model('User', UserSchema);

// Генерация JWT токена
const generateToken = (user) => {
    return jwt.sign(
        { 
            id: user._id, 
            username: user.username, 
            email: user.email,
            role: user.role 
        },
        process.env.JWT_SECRET || 'ganrenhub_secret_key',
        { expiresIn: '7d' }
    );
};

// Middleware для проверки аутентификации
const authMiddleware = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        
        if (!token) {
            return res.status(401).json({ success: false, message: 'Требуется авторизация' });
        }
        
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'ganrenhub_secret_key');
        const user = await User.findOne({ _id: decoded.id, 'tokens.token': token });
        
        if (!user) {
            throw new Error();
        }
        
        req.user = user;
        req.token = token;
        next();
    } catch (e) {
        res.status(401).json({ success: false, message: 'Требуется авторизация' });
    }
};

// API маршруты

// Регистрация
app.post('/api/register', async (req, res) => {
    try {
        const { username, email, password } = req.body;
        
        // Валидация данных
        if (!username || !email || !password) {
            return res.status(400).json({ 
                success: false, 
                message: 'Заполните все поля' 
            });
        }
        
        if (username.length < 3) {
            return res.status(400).json({ 
                success: false, 
                message: 'Имя пользователя должно содержать минимум 3 символа' 
            });
        }
        
        if (!validator.isEmail(email)) {
            return res.status(400).json({ 
                success: false, 
                message: 'Введите корректный email' 
            });
        }
        
        if (password.length < 6) {
            return res.status(400).json({ 
                success: false, 
                message: 'Пароль должен содержать минимум 6 символов' 
            });
        }
        
        // Проверка существования пользователя
        const existingUser = await User.findOne({ $or: [{ username }, { email }] });
        if (existingUser) {
            return res.status(400).json({ 
                success: false, 
                message: 'Пользователь с таким именем или email уже существует' 
            });
        }
        
        // Создание пользователя
        const user = new User({
            username,
            email,
            password
        });
        
        await user.save();
        
        // Генерация токена
        const token = generateToken(user);
        
        res.status(201).json({
            success: true,
            token,
            user: {
                id: user._id,
                username: user.username,
                email: user.email,
                role: user.role
            }
        });
    } catch (e) {
        console.error(e);
        res.status(500).json({ 
            success: false, 
            message: 'Ошибка сервера при регистрации' 
        });
    }
});

// Вход
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ 
                success: false, 
                message: 'Заполните все поля' 
            });
        }
        
        // Поиск пользователя
        const user = await User.findOne({ username });
        if (!user) {
            return res.status(400).json({ 
                success: false, 
                message: 'Неверные учетные данные' 
            });
        }
        
        // Проверка пароля
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ 
                success: false, 
                message: 'Неверные учетные данные' 
            });
        }
        
        // Обновляем время последнего входа
        user.lastLogin = new Date();
        await user.save();
        
        // Генерация токена
        const token = generateToken(user);
        
        res.json({
            success: true,
            token,
            user: {
                id: user._id,
                username: user.username,
                email: user.email,
                role: user.role
            }
        });
    } catch (e) {
        console.error(e);
        res.status(500).json({ 
            success: false, 
            message: 'Ошибка сервера при входе' 
        });
    }
});

// Получение информации о текущем пользователе
app.get('/api/me', authMiddleware, async (req, res) => {
    res.json({
        success: true,
        user: {
            id: req.user._id,
            username: req.user.username,
            email: req.user.email,
            role: req.user.role,
            createdAt: req.user.createdAt,
            lastLogin: req.user.lastLogin
        }
    });
});

// Запуск сервера
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`GANRENhub server running on port ${PORT}`);
});