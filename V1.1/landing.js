// Hero job ticket: slowly moves through the production steps, then loops.
(function () {
  const steps = Array.from(document.querySelectorAll('#ticketSteps li'));
  const bar = document.getElementById('ticketBar');
  const state = document.getElementById('ticketState');
  if (!steps.length || !bar || !state) return;

  const labels = ['Received', 'Verified', 'Printing', 'Checking', 'Ready'];
  let current = 2;

  function render() {
    steps.forEach(function (li, i) {
      li.classList.toggle('done', i < current);
      li.classList.toggle('current', i === current);
    });
    bar.style.width = ((current + 1) / steps.length) * 100 + '%';
    state.textContent = labels[current];
  }

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    render();
    return;
  }

  setInterval(function () {
    current = (current + 1) % steps.length;
    render();
  }, 2600);

  render();
})();
