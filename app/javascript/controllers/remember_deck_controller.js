import { Controller } from "@hotwired/stimulus"

// Shows today's remembers one card at a time. Tap a card to flip it to its
// background notes; swipe, use the arrow keys, or the Prev/Next buttons to
// move between cards. After the last card comes an "All done!" panel. Without
// JS the page shows every card in a plain list.
//
// The place in the deck is saved in localStorage for the day, so a reload
// returns to the same card (or to "All done!"). A card that wasn't in the deck
// when the place was saved (a new remember) is shown first instead.
export default class extends Controller {
  static targets = [ "card", "done", "controls", "counter", "progress", "prev", "next" ]
  static values = { key: String, date: String }

  connect() {
    this.element.classList.add("deck--ready")
    this.controlsTargets.forEach((el) => { el.hidden = false })
    this.show(this.savedIndex())
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
    this.save()
  }

  cardIds() {
    return this.cardTargets.map((card) => card.dataset.rememberId)
  }

  // Where to open the deck: today's saved place, else the first card.
  savedIndex() {
    const saved = this.load()
    if (!saved || saved.date !== this.dateValue) return 0

    const ids = this.cardIds()
    const newIndex = ids.findIndex((id) => !saved.ids.includes(id))
    if (newIndex !== -1) return newIndex

    if (saved.at === "done") return ids.length
    const index = ids.indexOf(saved.at)
    return index === -1 ? 0 : index
  }

  load() {
    try {
      return JSON.parse(localStorage.getItem(this.keyValue))
    } catch {
      return null
    }
  }

  save() {
    if (!this.keyValue) return
    const ids = this.cardIds()
    const at = this.index === ids.length ? "done" : ids[this.index]
    try {
      localStorage.setItem(this.keyValue, JSON.stringify({ date: this.dateValue, ids, at }))
    } catch {
      // Storage can be unavailable (private mode); the deck still works.
    }
  }

  setFlipped(card, flipped) {
    card.classList.toggle("is-flipped", flipped)
    card.querySelector(".deck-card-inner").setAttribute("aria-pressed", String(flipped))
  }
}
