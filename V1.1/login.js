// login.js
const ADMIN_EMAIL = 'admin@gmail.com';  // change to your admin email
const ADMIN_PASSWORD = 'admin123';                // change to your admin password

const form = document.getElementById('loginForm');
const errorBanner = document.getElementById('errorBanner');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');

function showError(message) {
  errorBanner.textContent = message;
  errorBanner.classList.add('show');
  emailInput.classList.add('error');
  passwordInput.classList.add('error');
}

function clearError() {
  errorBanner.classList.remove('show');
  emailInput.classList.remove('error');
  passwordInput.classList.remove('error');
}

form.addEventListener('submit', function (e) {
  e.preventDefault();
  clearError();

  const email = emailInput.value.trim();
  const password = passwordInput.value;

  if (!email || !password) {
    showError('Please enter both email and password.');
    return;
  }

  // 1) Admin login
  if (email.toLowerCase() === ADMIN_EMAIL.toLowerCase() && password === ADMIN_PASSWORD) {
    localStorage.removeItem('richersCurrentUser');
    localStorage.setItem('richersRole', 'admin');
    window.location.href = 'dashboard.html';
    return;
  }

  // 2) Customer login: only accounts created via the signup page are valid
  const accounts = JSON.parse(localStorage.getItem('richersAccounts') || '[]');

  const match = accounts.find(function (acc) {
    return acc.email.toLowerCase() === email.toLowerCase() && acc.password === password;
  });

  if (!match) {
    showError('Invalid email or password. Please create an account first.');
    return;
  }

  localStorage.setItem('richersCurrentUser', JSON.stringify(match));
  localStorage.setItem('richersRole', 'customer');
  window.location.href = 'order.html';
});