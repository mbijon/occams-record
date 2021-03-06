require 'test_helper'

class BatchTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_find_in_batches_with_block
    num_calls = 0
    widgets = []
    OccamsRecord.query(Widget.order('name')).find_in_batches(batch_size: 3) do |batch|
      num_calls += 1
      batch.each { |widget| widgets << widget.name }
    end
    assert_equal 2, num_calls
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F'], widgets
  end

  def test_find_each_with_block
    widgets = []
    OccamsRecord.query(Widget.order('name')).find_each(batch_size: 3) do |widget|
      widgets << widget.name
    end
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F'], widgets
  end

  def test_find_in_batches_with_enum
    widgets = OccamsRecord.
      query(Widget.order('name')).
      find_in_batches.
      reduce([]) { |a, batch|
        a + batch.map(&:name)
      }
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F'], widgets
  end

  def test_find_each_with_enum
    widgets = OccamsRecord.
      query(Widget.order('name')).
      find_each.
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F'], widgets
  end

  def test_batches_with_offset
    widgets = OccamsRecord.
      query(Widget.order('name').offset(3)).
      find_each.
      map(&:name)
    assert_equal ['Widget D', 'Widget E', 'Widget F'], widgets
  end

  def test_batches_with_limit
    widgets = OccamsRecord.
      query(Widget.order('name').limit(3)).
      find_each.
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C'], widgets
  end

  def test_batches_with_batch_remainder
    widgets = OccamsRecord.
      query(Widget.order('name').limit(5)).
      find_each(batch_size: 3).
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E'], widgets
  end

  def test_eager_loading_with_batches
    widgets = OccamsRecord.
      query(Widget.order('name').limit(3).offset(1)).
      eager_load(:category).
      eager_load(:detail).
      eager_load(:line_items) {
        eager_load(:order)
      }.
      find_each(batch_size: 2).
      map { |w|
        {name: w.name, category: w.category.name, detail: w.detail.text, line_items: w.line_items.map { |li|
          {amount: li.amount.to_i, total: li.order.amount.to_i}
        }}
      }

    assert_equal [
      {name: 'Widget B', category: 'Foo', detail: 'All about Widget B', line_items: []},
      {name: 'Widget C', category: 'Foo', detail: 'All about Widget C', line_items: [
        {amount: 200, total: 520}
      ]},
      {name: 'Widget D', category: 'Bar', detail: 'All about Widget D', line_items: [
        {amount: 300, total: 520}
      ]},
    ], widgets
  end
end
