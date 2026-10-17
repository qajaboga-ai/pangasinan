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
  const shortName = formatGreetingName(currentUser.fullName);
  document.getElementById('userGreeting').textContent = 'Hi, ' + shortName + ' (Customer)';
  document.getElementById('noteName').textContent = shortName;
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
  } else {
    uploadConfirm.classList.remove('show');
  }
});

// ===== Basic form check =====
function getMissing() {
  const missing = [];
  [['serviceType', 'service type'], ['paperType', 'paper type'], ['colorOption', 'color option'], ['bindingOption', 'binding / finishing']]
    .forEach(function (f) {
      if (!document.getElementById(f[0]).value) missing.push(f[1]);
    });
  const copies = parseInt(document.getElementById('copiesInput').value, 10);
  if (!copies || copies < 1) missing.push('number of copies');
  if (!document.getElementById('pickupInput').value.trim()) missing.push('pickup date');
  if (fileInput.files.length === 0) missing.push('your file');
  return missing;
}

// ===== Submit order =====
document.getElementById('orderForm').addEventListener('submit', function (e) {
  e.preventDefault();
  const missing = getMissing();
  if (missing.length > 0) {
    alert('Please complete the form first. Still needed: ' + missing.join(', ') + '.');
    return;
  }
  alert('Printing order submitted successfully! You can track its progress under "My Orders".');
});