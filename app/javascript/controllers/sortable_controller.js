import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { patch } from "@rails/request.js"

// Usage: data-controller="sortable" on the board,
// each column's list has data-sortable-target="list" and data-status="...",
// each card has data-move-url and data-movable.
export default class extends Controller {
  static targets = ["list", "count"]

  connect() {
    this.sortables = this.listTargets.map((list) =>
      Sortable.create(list, {
        group: "kanban",                                   // allow moving between columns
        sort: false,                                       // order inside a column is not saved
        animation: 150,
        draggable: ".kanban-card[data-movable='true']",    // only allowed cards can be dragged
        ghostClass: "kanban-ghost",
        onEnd: (event) => this.moved(event)
      })
    )
  }

  disconnect() {
    this.sortables.forEach((sortable) => sortable.destroy())
  }

  async moved(event) {
    const { item, from, to, oldIndex } = event
    if (from === to) return

    this.updateCounts()

    try {
      const response = await patch(item.dataset.moveUrl, {
        body: JSON.stringify({ status: to.dataset.status }),
        contentType: "application/json",
        responseKind: "json"
      })

      if (!response.ok) throw new Error("Request failed")
    } catch (error) {
      // put the card back where it came from
      from.insertBefore(item, from.children[oldIndex] || null)
      this.updateCounts()
      alert("Could not move this task. Please try again.")
    }
  }

  updateCounts() {
    this.countTargets.forEach((counter) => {
      const list = this.listTargets.find((l) => l.dataset.status === counter.dataset.status)
      counter.textContent = list.querySelectorAll(".kanban-card").length
    })
  }
}