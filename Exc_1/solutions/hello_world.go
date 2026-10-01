package main

import "fmt"

// Exercise: Create a hello world program that prints the contents of a struct using a method with a receiver type

type HelloWorld struct {
	Greeting string
	To       string
}

func (h HelloWorld) Print() {
	fmt.Printf("%s, %s!", h.Greeting, h.To)
}

func main() {
	hw := HelloWorld{
		Greeting: "Hello",
		To:       "World",
	}

	hw.Print()
}
