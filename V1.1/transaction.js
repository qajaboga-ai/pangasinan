// transaction.js — Transaction Details page interactivity
// Frontend-only for now: updates the UI immediately, nothing is saved
// to a server/database yet. Swap the two TODO spots below when a
// backend/API is ready.

document.addEventListener("DOMContentLoaded", () => {
  const recordPaymentBtn = document.getElementById("record-payment-btn");
  const paymentBadge = document.getElementById("payment-status-badge");
  const advanceBtn = document.getElementById("advance-step-btn");
  const tracker = document.getElementById("tracker");

  const STEP_LABELS = [
    { done: "Order Received" },
    { done: "File Verified" },
    { done: "Printing In Progress" },
    { done: "Quality Check" },
    { done: "Ready for Pickup" }
  ];

  // ---------- Record Cash Payment ----------
  if (recordPaymentBtn) {
    recordPaymentBtn.addEventListener("click", () => {
      const amount = recordPaymentBtn.dataset.amount || "";

      // Update payment badge
      paymentBadge.textContent = "PAID";
      paymentBadge.classList.remove("unpaid");
      paymentBadge.classList.add("paid");

      // Disable the button so it can't be recorded twice
      recordPaymentBtn.textContent = `Payment Recorded (${amount})`;
      recordPaymentBtn.disabled = true;

      // TODO: once a backend exists, send a request here, e.g.
      // fetch("/api/transactions/RPS-0891/payment", { method: "POST" })
    });
  }

  // ---------- Advance Workflow Step ----------
  if (advanceBtn && tracker) {
    const steps = Array.from(tracker.querySelectorAll(".tracker-step"));

    advanceBtn.addEventListener("click", () => {
      const currentIndex = steps.findIndex((s) => s.classList.contains("current"));
      if (currentIndex === -1 || currentIndex >= steps.length - 1) return;

      // Mark current step as done
      const currentStep = steps[currentIndex];
      currentStep.classList.remove("current");
      currentStep.classList.add("done");
      currentStep.querySelector(".step-icon").textContent = "✓";
      currentStep.querySelector(".step-sub").textContent = getTimestamp();

      // Advance to next step
      const nextStep = steps[currentIndex + 1];
      nextStep.classList.remove("pending");
      nextStep.classList.add("current");
      nextStep.querySelector(".step-icon").textContent = "●";
      nextStep.querySelector(".step-sub").textContent = "Current Step";

      // If we just reached the last step, disable the advance button
      if (currentIndex + 1 === steps.length - 1) {
        advanceBtn.textContent = "Workflow Complete";
        advanceBtn.disabled = true;
      }

      // TODO: once a backend exists, send a request here, e.g.
      // fetch("/api/transactions/RPS-0891/advance-step", { method: "POST" })
    });
  }

  function getTimestamp() {
    const now = new Date();
    let hours = now.getHours();
    const minutes = now.getMinutes().toString().padStart(2, "0");
    const ampm = hours >= 12 ? "PM" : "AM";
    hours = hours % 12 || 12;
    return `${hours}:${minutes} ${ampm}`;
  }
});