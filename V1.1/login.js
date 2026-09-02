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

  // Only accounts created via the signup page are valid
  const accounts = JSON.parse(localStorage.getItem('richersAccounts') || '[]');

  const match = accounts.find(function (acc) {
    return acc.email.toLowerCase() === email.toLowerCase() && acc.password === password;
  });

  if (!match) {
    showError('Invalid email or password. Please create an account first.');
    return;
  }

  // Store the logged-in session
  localStorage.setItem('richersCurrentUser', JSON.stringify(match));

  // Redirect to the customer ordering page
  window.location.href = 'order.html';
});
