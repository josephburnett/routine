require "application_system_test_case"

class RememberDeckTest < ApplicationSystemTestCase
  setup do
    user = users(:one)
    # decay 1.0 always shows today; pinned sorts first
    Remember.create!(user: user, namespace: "deck", state: "pinned", decay: 1.0,
                     description: "First deck card", background: "Why the first card matters")
    Remember.create!(user: user, namespace: "deck", state: "floating", decay: 1.0,
                     description: "Another deck card", background: "Background two")
    Remember.create!(user: user, namespace: "deck", state: "floating", decay: 1.0,
                     description: "Yet another deck card", background: "Background three")

    visit login_path
    fill_in "name", with: user.name
    fill_in "password", with: "password"
    click_on "Login"
    assert_no_current_path login_path

    visit display_remembers_path(namespace: "deck")
    assert_selector ".deck.deck--ready"
  end

  test "shows one card at a time with a counter" do
    assert_selector ".deck-card", count: 1, visible: true
    assert_selector ".deck-card", text: "First deck card"
    assert_selector ".deck-counter", text: "1 / 3"
    assert_button "← Prev", disabled: true
    assert_button "Next →", disabled: false
  end

  test "tapping a card flips it to the background and back" do
    find(".deck-card-inner", visible: true).click
    assert_selector ".deck-card.is-flipped .deck-card-inner[aria-pressed=true]"
    assert_selector ".deck-back", text: "Why the first card matters"

    find(".deck-card-inner", visible: true).click
    assert_no_selector ".deck-card.is-flipped"
  end

  test "next and prev move through the deck and stop at the ends" do
    click_on "Next →"
    assert_selector ".deck-counter", text: "2 / 3"
    click_on "Next →"
    assert_selector ".deck-counter", text: "3 / 3"
    assert_button "Next →", disabled: true

    click_on "← Prev"
    assert_selector ".deck-counter", text: "2 / 3"
    assert_selector ".deck-card", count: 1, visible: true
  end

  test "moving to another card unflips the one you left" do
    find(".deck-card-inner", visible: true).click
    assert_selector ".deck-card.is-flipped"

    click_on "Next →"
    click_on "← Prev"
    assert_selector ".deck-card", text: "First deck card"
    assert_no_selector ".deck-card.is-flipped"
  end

  test "arrow keys move between cards" do
    find("body").send_keys(:arrow_right)
    assert_selector ".deck-counter", text: "2 / 3"
    find("body").send_keys(:arrow_left)
    assert_selector ".deck-counter", text: "1 / 3"
  end

  test "swiping moves between cards without flipping them" do
    swipe(-200)
    assert_selector ".deck-counter", text: "2 / 3"

    swipe(200)
    assert_selector ".deck-counter", text: "1 / 3"
    assert_no_selector ".deck-card.is-flipped"
  end

  private

  def swipe(dx)
    card = find(".deck-card-inner", visible: true).native
    page.driver.browser.action.move_to(card).click_and_hold.move_by(dx, 0).release.perform
  end
end
