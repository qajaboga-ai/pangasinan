// ===== Auth guard: only logged-in users (from login.js) can view this page =====
const currentUser = JSON.parse(localStorage.getItem('richersCurrentUser') || 'null');

if (!currentUser) {
  window.location.href = 'login.html';
}

// ===== Greeting =====
function formatGreetingName(fullName) {
  const parts = fullName.trim().split(/\s+/);
  if (parts.length === 1) return parts[0];
  const last = parts.pop();
  return parts.join(' ') + ' ' + last.charAt(0).toUpperCase() + '.';
}

if (currentUser) {
  document.getElementById('userGreeting').textContent =
    'Hi, ' + formatGreetingName(currentUser.fullName) + ' (Customer)';
}

// ===== Logout =====
document.getElementById('logoutLink').addEventListener('click', function (e) {
  e.preventDefault();
  localStorage.removeItem('richersCurrentUser');
  window.location.href = 'login.html';
});

// ===== File upload mock =====
const browseBtn = document.getElementById('browseBtn');
const fileInput = document.getElementById('fileInput');
const uploadConfirm = document.getElementById('uploadConfirm');

browseBtn.addEventListener('click', function () {
  fileInput.click();
});

fileInput.addEventListener('change', function () {
  if (fileInput.files.length > 0) {
    const file = fileInput.files[0];
    const sizeMB = (file.size / (1024 * 1024)).toFixed(1);
    uploadConfirm.textContent = '✓ ' + file.name + ' (' + sizeMB + 'MB) Uploaded';
    uploadConfirm.classList.add('show');
  }
});

// ===== Submit order =====
document.getElementById('orderForm').addEventListener('submit', function (e) {
  e.preventDefault();
  alert('Printing order submitted successfully! You can track its progress under "My Orders".');
});
