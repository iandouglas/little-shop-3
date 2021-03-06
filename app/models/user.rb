class User < ApplicationRecord
  validates_presence_of :name,
                        :street,
                        :city,
                        :state,
                        :zipcode,
                        :role

  validates :email, presence: true, uniqueness: true

  has_many :orders
  has_many :items

  has_secure_password allow_blank: true

  enum role: ['user', 'merchant', 'admin']

  def self.permit_email?(email)
    if self.find_by(email: email)
      return false
    end
    true
  end

  def disable_merchant_items
    items.each {|item| item.disable}
  end

  def enable_merchant_items
    items.each {|item| item.enable}
  end

  def pending_orders
    #selects pending orders where the user id is the merchant id
    Order.joins(:items)
         .where('items.user_id = ? AND orders.status = 0',self.id)
         .distinct
  end

  def top_five_items_sold
    self.items
    .select("items.*, SUM(order_items.quantity) as quantity_sold")
    .joins(:order_items)
    .group("items.id")
    .order("quantity_sold DESC, items.name ASC")
    .limit(5)
  end

  def percent_inventory_sold
    inventory = self.items.sum(:quantity)

    items_sold / (inventory.to_f + items_sold) * 100
  end

  def items_sold
    self.items
    .joins(:order_items)
    .where("order_items.fulfilled = true")
    .sum("order_items.quantity")
  end

  def top_three_states_with_quantity_sold
    self.items
    .joins(order_items: {order: :user})
    .select("users.state, SUM(order_items.quantity) as quantity_sold")
    .group("users.state")
    .order("quantity_sold DESC")
    .limit(3)
  end

  def best_customer_by_orders
    self.items
    .joins(order_items: {order: :user})
    .select("users.name, COUNT(orders.*) as order_count")
    .group("users.name")
    .order("order_count DESC")
    .limit(1)
    .first
  end

  def best_customer_by_items
    self.items
    .joins(order_items: {order: :user})
    .select("users.name, SUM(order_items.quantity) as items_ordered")
    .group("users.name")
    .order("items_ordered DESC")
    .limit(1)
    .first
  end

  def best_customers_by_revenue
    self.items
    .joins(order_items: {order: :user})
    .select("users.name as name, SUM(order_items.quantity * order_items.order_price) as revenue")
    .group("users.name")
    .order("revenue DESC")
    .limit(3)
  end
end
