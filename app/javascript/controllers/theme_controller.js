import { Controller } from "@hotwired/stimulus"

// Toggles light/dark by setting data-theme on <html> and remembering the choice.
export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.render()
  }

  toggle() {
    const next = this.current === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next

    try {
      localStorage.setItem("theme", next)
    } catch (error) {
      // storage can be blocked; the toggle still works for this visit
    }

    this.render()
  }

  get current() {
    return document.documentElement.dataset.theme || "light"
  }

  render() {
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.current === "dark" ? "☀" : "☾"
    }
  }
}