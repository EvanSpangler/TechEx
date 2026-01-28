package main

import (
	"net/http"
	"os"

	controller "github.com/jeffthorne/tasky/controllers"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func index(c *gin.Context) {
	c.HTML(http.StatusOK, "login.html", nil)
}

// Health check endpoint
func healthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
		"app":    "tasky",
	})
}

// Endpoint to verify wizexercise.txt exists
func verifyWizExercise(c *gin.Context) {
	content, err := os.ReadFile("/app/wizexercise.txt")
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "wizexercise.txt not found",
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"status":  "verified",
		"content": string(content),
	})
}

func main() {
	godotenv.Overload()

	router := gin.Default()
	router.LoadHTMLGlob("assets/*.html")
	router.Static("/assets", "./assets")

	// Health and verification endpoints
	router.GET("/health", healthCheck)
	router.GET("/wizexercise", verifyWizExercise)

	// Main routes
	router.GET("/", index)
	router.GET("/todos/:userid", controller.GetTodos)
	router.GET("/todo/:id", controller.GetTodo)
	router.POST("/todo/:userid", controller.AddTodo)
	router.DELETE("/todo/:userid/:id", controller.DeleteTodo)
	router.DELETE("/todos/:userid", controller.ClearAll)
	router.PUT("/todo", controller.UpdateTodo)

	// Auth routes
	router.POST("/signup", controller.SignUp)
	router.POST("/login", controller.Login)
	router.GET("/todo", controller.Todo)

	router.Run(":8080")
}
