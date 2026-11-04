require "test_helper"

class RemembersDisplayTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
    # decay 1.0 always shows today, so these cards are always in the deck
    @pinned = Remember.create!(user: @user, namespace: "deck", state: "pinned", decay: 1.0,
                               description: "Pinned deck card", background: "First line\n\nSecond paragraph")
    @child = Remember.create!(user: @user, namespace: "deck.child", state: "floating", decay: 1.0,
                              description: "Child deck card", background: "")
  end

  test "renders a card deck for today's remembers" do
    get display_remembers_path(namespace: "deck")
    assert_response :success

    assert_select "section.deck[data-controller=remember-deck]" do
      assert_select ".deck-card", 2
      assert_select ".deck-card button.deck-card-inner[aria-pressed=false]", 2
      assert_select ".deck-card a.deck-details[href=?]", remember_path(@pinned)
    end
    assert_select ".deck-subtitle", text: /deck\s+·\s+2 cards/
  end

  test "card front shows the description, namespace and pinned state" do
    get display_remembers_path(namespace: "deck")

    assert_select ".deck-card", text: /Pinned deck card/ do
      assert_select ".deck-front .deck-description", "Pinned deck card"
      assert_select ".deck-chip-pinned", text: /Pinned/
      # Same namespace as the page, so no namespace chip
      assert_select ".deck-chip:not(.deck-chip-pinned)", 0
    end

    assert_select ".deck-card", text: /Child deck card/ do
      assert_select ".deck-chip", "deck.child"
      assert_select ".deck-chip-pinned", 0
    end
  end

  test "card back shows the background, or a note when there is none" do
    get display_remembers_path(namespace: "deck")

    assert_select ".deck-card", text: /Pinned deck card/ do
      assert_select ".deck-back .deck-background", text: /First line\s+Second paragraph/
    end
    # Line breaks reach the page as-is; CSS (pre-wrap) shows them
    assert_includes response.body, "First line\n\nSecond paragraph"
    assert_select ".deck-card", text: /Child deck card/ do
      assert_select ".deck-back .deck-background-empty", "No background notes."
    end
  end

  test "navigation controls are hidden until the deck script runs" do
    get display_remembers_path(namespace: "deck")

    assert_select ".deck-controls[hidden]"
    assert_select ".deck-progress[hidden]"
    assert_select "button[data-action='remember-deck#prev']"
    assert_select "button[data-action='remember-deck#next']"
  end

  test "root display says all namespaces" do
    get display_remembers_path
    assert_select ".deck-subtitle", text: /All namespaces/
  end

  test "escapes remember text" do
    Remember.create!(user: @user, namespace: "deck", state: "floating", decay: 1.0,
                     description: "<script>alert(1)</script>", background: "<b>bold</b>")
    get display_remembers_path(namespace: "deck")

    assert_no_match "<script>alert(1)</script>", response.body
    assert_select ".deck-background b", 0
  end

  test "shows the empty state when nothing is due" do
    get display_remembers_path(namespace: "nothing.here")

    assert_select ".deck", 0
    assert_select ".empty-state h3", "Nothing to remember today"
  end
end
