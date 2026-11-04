import { Controller } from "@hotwired/stimulus"

// Adds a List / Grid switch above every project, user and task list.
// The choice is remembered per list type in the browser (localStorage).
const LISTS = {
  ".project-grid": "projects",
  ".user-grid": "users",
  ".task-list": "tasks"
}

const ICONS = {
  list: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/></svg>',
  grid: '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/></svg>'
}

export default class extends Controller {
  connect() {
    // Turbo can restore a cached page that already contains a switch
    this.element.querySelectorAll(".view-switch").forEach((el) => el.remove())

    Object.entries(LISTS).forEach(([selector, key]) => {
      const list = this.element.querySelector(selector)
      if (list) list.before(this.build(key))
    })
  }

  current(key) {
    return document.documentElement.dataset["view" + this.cap(key)] === "grid" ? "grid" : "list"
  }

  cap(key) {
    return key.charAt(0).toUpperCase() + key.slice(1)
  }

  build(key) {
    const bar = document.createElement("div")
    bar.className = "view-switch"
    bar.innerHTML =
      '<div class="view-switch-inner" role="group" aria-label="Change layout">' +
      ["list", "grid"].map((mode) =>
        `<button type="button" data-mode="${mode}" aria-label="${mode} view" title="${mode === "list" ? "List" : "Grid"} view">${ICONS[mode]}<span>${mode === "list" ? "List" : "Grid"}</span></button>`
      ).join("") +
      "</div>"

    bar.querySelectorAll("button").forEach((button) => {
      button.addEventListener("click", () => this.set(key, button.dataset.mode, bar))
    })

    this.mark(bar, this.current(key))
    return bar
  }

  set(key, mode, bar) {
    document.documentElement.dataset["view" + this.cap(key)] = mode

    try {
      localStorage.setItem("view-" + key, mode)
    } catch (e) {}

    this.mark(bar, mode)
  }

  mark(bar, mode) {
    bar.querySelectorAll("button").forEach((button) => {
      button.setAttribute("aria-pressed", button.dataset.mode === mode ? "true" : "false")
    })
  }
}