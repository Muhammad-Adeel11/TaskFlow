import { Controller } from "@hotwired/stimulus"

// Pins / unpins the sidebar. Hovering reveals it with CSS alone;
// clicking the icon keeps it open and remembers the choice.
export default class extends Controller {
  connect() {
    this.sync()
  }

  toggle() {
    const root = document.documentElement
    const pinned = root.dataset.sidebar === "pinned"

    if (pinned) {
      delete root.dataset.sidebar
    } else {
      root.dataset.sidebar = "pinned"
    }

    try {
      localStorage.setItem("sidebar", pinned ? "auto" : "pinned")
    } catch (e) {}

    this.sync()
  }

  sync() {
    const pinned = document.documentElement.dataset.sidebar === "pinned"

    this.element.querySelectorAll("[data-action~='sidebar#toggle']").forEach((button) => {
      button.setAttribute("aria-pressed", pinned ? "true" : "false")
    })
  }
}