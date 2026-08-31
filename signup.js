// ===== Terms modal controls =====
const termsModal = document.getElementById('termsModal');
const termsLink = document.getElementById('termsLink');
const modalClose = document.getElementById('modalClose');
const modalAgreeBtn = document.getElementById('modalAgreeBtn');
const agreeCheckbox = document.getElementById('agreeCheckbox');

function openTermsModal() {
  termsModal.classList.add('open');
}

function closeTermsModal() {
  termsModal.classList.remove('open');
}

termsLink.addEventListener('click', function (e) {
  e.preventDefault();
  openTermsModal();
});

modalClose.addEventListener('click', closeTermsModal);

// Clicking outside the modal box closes it
termsModal.addEventListener('click', function (e) {
  if (e.target === termsModal) {
    closeTermsModal();
  }
});

// "I Agree" inside the modal checks the box on the main form and closes the modal
modalAgreeBtn.addEventListener('click', function () {
  agreeCheckbox.checked = true;
  closeTermsModal();
});

// ===== Form validation + account creation =====
const form = document.getElementById('signupForm');
const successBox = document.getElementById('successBox');

const fields = {
  fullName: document.getElementById('fullName'),
  email: document.getElementById('email'),
  contact: document.getElementById('contact'),
  password: document.getElementById('password'),
  confirmPassword: document.getElementById('confirmPassword')
};

function showError(fieldKey, message) {
  const input = fields[fieldKey];
  const errorEl = document.getElementById(fieldKey + 'Error');
  input.classList.add('error');
  errorEl.textContent = message;
  errorEl.classList.add('show');
}

function clearError(fieldKey) {
  const input = fields[fieldKey];
  const errorEl = document.getElementById(fieldKey + 'Error');
  input.classList.remove('error');
  errorEl.classList.remove('show');
}

function clearAllErrors() {
  Object.keys(fields).forEach(clearError);
}

function isValidEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

form.addEventListener('submit', function (e) {
  e.preventDefault();
  clearAllErrors();
  successBox.classList.remove('show');

  let isValid = true;

  const fullName = fields.fullName.value.trim();
  const email = fields.email.value.trim();
  const contact = fields.contact.value.trim();
  const password = fields.password.value;
  const confirmPassword = fields.confirmPassword.value;

  if (!fullName) {
    showError('fullName', 'Full name is required.');
    isValid = false;
  }

  if (!email) {
    showError('email', 'Email address is required.');
    isValid = false;
  } else if (!isValidEmail(email)) {
    showError('email', 'Enter a valid email address.');
    isValid = false;
  }

  if (!contact) {
    showError('contact', 'Contact number is required.');
    isValid = false;
  }

  if (!password) {
    showError('password', 'Password is required.');
    isValid = false;
  } else if (password.length < 6) {
    showError('password', 'Password must be at least 6 characters.');
    isValid = false;
  }

  if (!confirmPassword) {
    showError('confirmPassword', 'Please confirm your password.');
    isValid = false;
  } else if (password !== confirmPassword) {
    showError('confirmPassword', 'Passwords do not match.');
    isValid = false;
  }

  // If terms not agreed, open the modal instead of just erroring
  if (!agreeCheckbox.checked) {
    openTermsModal();
    isValid = false;
  }

  if (!isValid) return;

  // Check for duplicate email in stored accounts
  const accounts = JSON.parse(localStorage.getItem('richersAccounts') || '[]');
  const alreadyExists = accounts.some(function (acc) {
    return acc.email.toLowerCase() === email.toLowerCase();
  });

  if (alreadyExists) {
    showError('email', 'An account with this email already exists.');
    return;
  }

  // Save the new account
  accounts.push({ fullName: fullName, email: email, contact: contact, password: password });
  localStorage.setItem('richersAccounts', JSON.stringify(accounts));

  // Show success and redirect to login
  successBox.textContent = 'Account created successfully! Redirecting to login...';
  successBox.classList.add('show');
  form.reset();

  setTimeout(function () {
    window.location.href = 'login.html';
  }, 1500);
});
