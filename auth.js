/**
 * GANRENhub Authentication Module v1.1
 * Исправление бесконечного редиректа
 */

const AUTH_CONFIG = {
    storageKey: 'ganrenhub_auth',
    credsKey: 'ganrenhub_credentials',
    tokenKey: 'ganrenhub_token',
    publicPages: ['index.html', 'regin.html', '404.html']
};

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    // Автозаполнение формы входа если есть сохраненные данные
    if (window.location.pathname.includes('index.html')) {
        const savedCreds = getSavedCredentials();
        if (savedCreds) {
            document.getElementById('username').value = savedCreds.username || '';
            document.getElementById('password').value = savedCreds.password || '';
            if (document.getElementById('remember')) {
                document.getElementById('remember').checked = savedCreds.remember || false;
            }
        }
    }

    // Настройка обработчиков выхода
    document.querySelectorAll('.logout-btn').forEach(btn => {
        btn.addEventListener('click', logout);
    });

    // Проверка авторизации для защищенных страниц
    protectRoutes();
});

function protectRoutes() {
    const currentPage = getCurrentPageName();
    
    // Если пользователь не авторизован и пытается получить доступ к защищенной странице
    if (!isAuthenticated() && !AUTH_CONFIG.publicPages.includes(currentPage)) {
        redirectToLogin();
        return;
    }

    // Если пользователь авторизован и пытается получить доступ к публичной странице
    if (isAuthenticated() && AUTH_CONFIG.publicPages.includes(currentPage)) {
        redirectToProfile();
    }
}

function getCurrentPageName() {
    return window.location.pathname.split('/').pop().split('?')[0];
}

function redirectToLogin() {
    if (!window.location.pathname.includes('index.html')) {
        window.location.href = 'index.html';
    }
}

function redirectToProfile() {
    if (!window.location.pathname.includes('profile.html')) {
        window.location.href = 'profile.html';
    }
}

function login(username, password, remember = false, token = null) {
    if (remember) {
        localStorage.setItem(AUTH_CONFIG.credsKey, JSON.stringify({
            username,
            password,
            remember: true
        }));
    } else {
        localStorage.removeItem(AUTH_CONFIG.credsKey);
    }
    
    localStorage.setItem(AUTH_CONFIG.storageKey, 'true');
    
    if (token) {
        localStorage.setItem(AUTH_CONFIG.tokenKey, token);
    }
    
    redirectToProfile();
}

function logout() {
    localStorage.removeItem(AUTH_CONFIG.storageKey);
    localStorage.removeItem(AUTH_CONFIG.tokenKey);
    redirectToLogin();
}

function isAuthenticated() {
    return localStorage.getItem(AUTH_CONFIG.storageKey) === 'true';
}

function getToken() {
    return localStorage.getItem(AUTH_CONFIG.tokenKey);
}

function getSavedCredentials() {
    const saved = localStorage.getItem(AUTH_CONFIG.credsKey);
    return saved ? JSON.parse(saved) : null;
}

// Экспорт для использования в других модулях
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        login,
        logout,
        isAuthenticated,
        getToken
    };
}