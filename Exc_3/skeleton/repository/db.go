package repository

import (
	"ordersystem/model"
	"time"
)

type DatabaseHandler struct {
	// drinks represent all available drinks
	drinks []model.Drink
	// orders serves as order history
	orders []model.Order
}

func NewDatabaseHandler() *DatabaseHandler {
	// Init the drinks slice with some test data
	// drinks := ...
	drinks := []model.Drink{
		{
			ID:          1,
			Description: "tasty beer",
			Name:        "Beer",
			Price:       3.5,
		},
		{
			ID:          2,
			Description: "Red Wine from the Burgenland",
			Name:        "Wine",
			Price:       4.0,
		},
		{
			ID:          3,
			Description: "Teste",
			Name:        "Cocktail",
			Price:       3.5,
		},
	}
	// Init orders slice with some test data
	orders := []model.Order{
		{
			DrinkID:   1,
			Amount:    10,
			CreatedAt: time.Now(),
		},
		{
			DrinkID:   2,
			Amount:    3,
			CreatedAt: time.Now().Add(-24 * time.Hour),
		},
		{
			DrinkID:   3,
			Amount:    4,
			CreatedAt: time.Now().Add(-48 * time.Hour),
		},
		{
			DrinkID:   2,
			Amount:    5,
			CreatedAt: time.Now().Add(-72 * time.Hour),
		},
	}

	return &DatabaseHandler{
		drinks: drinks,
		orders: orders,
	}
}

func (db *DatabaseHandler) GetDrinks() []model.Drink {
	return db.drinks
}

func (db *DatabaseHandler) GetOrders() []model.Order {
	return db.orders
}

func (db *DatabaseHandler) GetTotalledOrders() map[uint64]uint64 {
	totalOrders := make(map[uint64]uint64)

	for _, order := range db.orders {
		totalOrders[order.DrinkID] += order.Amount
	}
	return totalOrders
}

func (db *DatabaseHandler) AddOrder(order *model.Order) {
	db.orders = append(db.orders, *order)
}
