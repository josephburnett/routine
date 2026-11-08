import { Controller } from "@hotwired/stimulus"

// Shows today's remembers one card at a time. Tap a card to flip it to its
// background notes; swipe, use the arrow keys, or the Prev/Next buttons to
// move between cards. After the last card comes an "All done!" panel. Without
// JS the page shows every card in a plain list.
export default class extends Controller {
  static targets = [ "card", "done", "controls", "counter", "progress", "prev", "next" ]

  connect() {
    this.element.classList.add("deck--ready")
    this.controlsTargets.forEach((el) => { el.hidden = false })
    this.show(0)
  }

  disconnect() {
    this.element.classList.remove("deck--ready")
  }

  next() {
    this.go(this.index + 1, "next")
  }

  prev() {
    this.go(this.index - 1, "prev")
  }

  restart() {
    this.show(0, "prev")
  }

  flip(event) {
    // A swipe ends with a click on the card; don't flip for it.
    if (this.swiped) {
      this.swiped = false
      return
    }
    const card = event.currentTarget.closest(".deck-card")
    this.setFlipped(card, !card.classList.contains("is-flipped"))
  }

  keydown(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    }
  }

  pointerDown(event) {
    this.swiped = false
    this.startX = event.clientX
    this.startY = event.clientY
  }

  pointerUp(event) {
    if (this.startX == null) return
    const dx = event.clientX - this.startX
    const dy = event.clientY - this.startY
    this.startX = null
    if (Math.abs(dx) < 50 || Math.abs(dx) < Math.abs(dy)) return

    this.swiped = true
    if (dx < 0) {
      this.next()
    } else {
      this.prev()
    }
  }

  go(index, direction) {
    // index == cardTargets.length is the "All done!" panel
    if (index < 0 || index > this.cardTargets.length) return
    this.show(index, direction)
  }

  show(index, direction = null) {
    this.cardTargets.forEach((card, i) => {
      card.hidden = i !== index
      card.classList.remove("deck-card--from-next", "deck-card--from-prev")
      if (i !== index) this.setFlipped(card, false)
    })

    const total = this.cardTargets.length
    const done = index === total
    this.doneTarget.hidden = !done
    this.doneTarget.classList.remove("deck-card--from-next", "deck-card--from-prev")

    const shown = done ? this.doneTarget : this.cardTargets[index]
    if (direction) shown.classList.add(`deck-card--from-${direction}`)

    this.index = index
    this.counterTarget.textContent = done ? "Done" : `${index + 1} / ${total}`
    // The bar fills as cards are finished, so it completes on the last swipe.
    this.progressTarget.style.width = `${(index / total) * 100}%`
    this.prevTarget.disabled = index === 0
    this.nextTarget.disabled = done
  }

  setFlipped(card, flipped) {
    card.classList.toggle("is-flipped", flipped)
    card.querySelector(".deck-card-inner").setAttribute("aria-pressed", String(flipped))
  }
}
