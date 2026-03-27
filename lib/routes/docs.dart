final openApiSpec = r'''
{
  "openapi": "3.0.3",
  "info": {
    "title": "NeztMate Property Management API",
    "description": "Complete backend API for NeztMate - Property, Lease, Payment, Maintenance, Tasks, Community & Chat System (Nigeria-focused)",
    "version": "1.0.0",
    "contact": { "name": "NeztMate Team" }
  },
  "servers": [
    { "url": "http://localhost:8080", "description": "Local Development" },
    { "url": "https://api.neztmate.com", "description": "Production" }
  ],
  "security": [{ "bearerAuth": [] }],
  "paths": {
    "/auth/register": {
      "post": {
        "summary": "Register new user (Email/Password)",
        "tags": ["Auth"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["email", "password", "fullName", "role"],
                "properties": {
                  "email": { "type": "string", "format": "email" },
                  "password": { "type": "string", "minLength": 6 },
                  "fullName": { "type": "string" },
                  "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] },
                  "phone": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Registration successful",
            "content": { "application/json": { "schema": { "type": "object", "properties": { "accessToken": { "type": "string" }, "refreshToken": { "type": "string" }, "user": { "$ref": "#/components/schemas/User" } } } } }
          },
          "400": { "description": "Invalid input" },
          "409": { "description": "Email already exists" }
        }
      }
    },
    "/auth/login": {
      "post": {
        "summary": "Login with email and password",
        "tags": ["Auth"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["email", "password"],
                "properties": {
                  "email": { "type": "string" },
                  "password": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Login successful",
            "content": { "application/json": { "schema": { "type": "object", "properties": { "accessToken": { "type": "string" }, "refreshToken": { "type": "string" }, "user": { "$ref": "#/components/schemas/User" } } } } }
          },
          "401": { "description": "Invalid credentials" }
        }
      }
    },
    "/auth/social": {
      "post": {
        "summary": "Social login using Firebase ID Token",
        "tags": ["Auth"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["idToken", "role"],
                "properties": {
                  "idToken": { "type": "string" },
                  "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] },
                  "fullName": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Social login successful",
            "content": { "application/json": { "schema": { "type": "object", "properties": { "accessToken": { "type": "string" }, "refreshToken": { "type": "string" }, "user": { "$ref": "#/components/schemas/User" } } } } }
          },
          "400": { "description": "Invalid token or role" }
        }
      }
    },

    "/users/me": {
      "get": {
        "summary": "Get current authenticated user profile",
        "tags": ["Users"],
        "security": [{ "bearerAuth": [] }],
        "responses": {
          "200": { "description": "Success", "content": { "application/json": { "schema": { "type": "object", "properties": { "user": { "$ref": "#/components/schemas/User" } } } } } },
          "401": { "description": "Unauthorized" }
        }
      }
    },
    "/users/{id}": {
      "get": {
        "summary": "Get user by ID (self or admin only)",
        "tags": ["Users"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": {
          "200": { "description": "User details", "content": { "application/json": { "schema": { "type": "object", "properties": { "user": { "$ref": "#/components/schemas/User" } } } } } },
          "403": { "description": "Forbidden" },
          "404": { "description": "User not found" }
        }
      }
    },
    "/users/stats": {
      "get": {
        "summary": "Get user dashboard statistics (role-based)",
        "tags": ["Users"],
        "security": [{ "bearerAuth": [] }],
        "responses": {
          "200": { "description": "Dashboard stats", "content": { "application/json": { "schema": { "type": "object", "properties": { "stats": { "$ref": "#/components/schemas/UserStats" } } } } } },
          "401": { "description": "Unauthorized" }
        }
      }
    },

    "/properties": {
      "get": {
        "summary": "List properties (filtered by role)",
        "tags": ["Properties"],
        "responses": { "200": { "description": "List of properties" } }
      }
    },
    "/units/available": {
      "get": {
        "summary": "Get available units for rent (Tenant view)",
        "tags": ["Units"],
        "responses": { "200": { "description": "Available units with property info" } }
      }
    },
    "/units/my": {
      "get": {
        "summary": "Get my units (Landowner/Manager view with occupants)",
        "tags": ["Units"],
        "responses": { "200": { "description": "My units with occupants" } }
      }
    },

    "/applications": {
      "post": {
        "summary": "Submit lease application",
        "tags": ["Applications"],
        "security": [{ "bearerAuth": [] }],
        "requestBody": {
          "required": true,
          "content": { "application/json": { "schema": { "type": "object", "required": ["unitId"], "properties": { "unitId": { "type": "string" }, "message": { "type": "string" } } } } }
        },
        "responses": { "200": { "description": "Application submitted successfully" }, "401": { "description": "Unauthorized" } }
      }
    },
    "/applications/my": {
      "get": {
        "summary": "Get my lease applications",
        "tags": ["Applications"],
        "responses": { "200": { "description": "List of my applications" } }
      }
    },
    "/applications/{id}/approve": {
      "post": {
        "summary": "Approve application (Manager/Landowner)",
        "tags": ["Applications"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Application approved" } }
      }
    },

    "/leases": {
      "get": {
        "summary": "Get my leases",
        "tags": ["Leases"],
        "responses": { "200": { "description": "List of leases" } }
      }
    },

    "/maintenance": {
      "post": {
        "summary": "Submit maintenance request",
        "tags": ["Maintenance"],
        "security": [{ "bearerAuth": [] }],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["unitId", "description"],
                "properties": {
                  "unitId": { "type": "string" },
                  "description": { "type": "string" },
                  "priority": { "type": "string", "enum": ["Low", "Medium", "High", "Emergency"] }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Maintenance request submitted" } }
      }
    },
    "/maintenance/my": {
      "get": {
        "summary": "Get my maintenance requests (Tenant)",
        "tags": ["Maintenance"],
        "responses": { "200": { "description": "List of maintenance requests" } }
      }
    },
    "/maintenance/{id}/assign": {
      "patch": {
        "summary": "Assign maintenance to artisan (Manager)",
        "tags": ["Maintenance"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Maintenance assigned successfully" } }
      }
    },

    "/tasks": {
      "post": {
        "summary": "Create task (from maintenance request)",
        "tags": ["Tasks"],
        "responses": { "200": { "description": "Task created" } }
      }
    },
    "/tasks/my": {
      "get": {
        "summary": "Get tasks assigned to me (Artisan)",
        "tags": ["Tasks"],
        "responses": { "200": { "description": "List of assigned tasks" } }
      }
    },
    "/tasks/{id}/complete": {
      "patch": {
        "summary": "Mark task as completed",
        "tags": ["Tasks"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Task completed successfully" } }
      }
    },

    "/payments/initialize": {
      "post": {
        "summary": "Initialize rent or task payment with Paystack",
        "tags": ["Payments"],
        "security": [{ "bearerAuth": [] }],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["amount"],
                "properties": {
                  "leaseId": { "type": "string" },
                  "taskId": { "type": "string" },
                  "amount": { "type": "number" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Payment initialized successfully",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "authorization_url": { "type": "string" },
                    "reference": { "type": "string" }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/payments/me": {
      "get": {
        "summary": "Get my payment history",
        "tags": ["Payments"],
        "responses": { "200": { "description": "Payment history" } }
      }
    },
    "/payments/{id}/mark-paid": {
      "patch": {
        "summary": "Manually mark payment as paid",
        "tags": ["Payments"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Payment marked as paid" } }
      }
    },
    "/payments/withdrawals": {
      "post": {
        "summary": "Request withdrawal (Landowner/Manager)",
        "tags": ["Payments"],
        "security": [{ "bearerAuth": [] }],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["amount"],
                "properties": { "amount": { "type": "number" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Withdrawal request submitted" } }
      }
    },
    "/payments/withdrawals/me": {
      "get": {
        "summary": "Get my withdrawal requests",
        "tags": ["Payments"],
        "responses": { "200": { "description": "Withdrawal history" } }
      }
    },
    "/payments/webhook": {
      "post": {
        "summary": "Paystack Webhook (Public - No authentication required)",
        "tags": ["Payments"],
        "responses": { "200": { "description": "Webhook received successfully" } }
      }
    },

    "/messages/chats": {
      "get": {
        "summary": "Get chat list (inbox)",
        "tags": ["Messages"],
        "responses": { "200": { "description": "Chat list" } }
      }
    },
    "/messages/conversation/{receiverId}": {
      "get": {
        "summary": "Get full conversation with a user",
        "tags": ["Messages"],
        "parameters": [{ "name": "receiverId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Conversation messages" } }
      }
    },
    "/messages": {
      "post": {
        "summary": "Send a new message",
        "tags": ["Messages"],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["receiverId", "content"],
                "properties": {
                  "receiverId": { "type": "string" },
                  "content": { "type": "string" },
                  "propertyId": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Message sent successfully" } }
      }
    },

    "/notifications": {
      "get": {
        "summary": "Get my notifications",
        "tags": ["Notifications"],
        "responses": { "200": { "description": "Notifications list" } }
      }
    },
    "/notifications/{id}/read": {
      "patch": {
        "summary": "Mark single notification as read",
        "tags": ["Notifications"],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Notification marked as read" } }
      }
    },
    "/notifications/read-all": {
      "patch": {
        "summary": "Mark all notifications as read",
        "tags": ["Notifications"],
        "responses": { "200": { "description": "All notifications marked as read" } }
      }
    },

    "/community/posts": {
      "post": {
        "summary": "Create community post",
        "tags": ["Community"],
        "responses": { "200": { "description": "Post created" } }
      }
    },
    "/community/posts/property/{propertyId}": {
      "get": {
        "summary": "Get posts for a specific property",
        "tags": ["Community"],
        "parameters": [{ "name": "propertyId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "List of posts" } }
      }
    },
    "/community/posts/{postId}/comments": {
      "post": {
        "summary": "Add comment to a post",
        "tags": ["Community"],
        "parameters": [{ "name": "postId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Comment added" } }
      }
    }
  },
  "components": {
    "schemas": {
      "User": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "email": { "type": "string" },
          "fullName": { "type": "string" },
          "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] },
          "phone": { "type": "string" },
          "profilePhotoUrl": { "type": "string" },
          "verifiedIdentity": { "type": "boolean" },
          "rating": { "type": "number" },
          "createdAt": { "type": "string", "format": "date-time" }
        }
      },
      "UserStats": {
        "type": "object",
        "properties": {
          "totalProperties": { "type": "integer" },
          "totalRevenue": { "type": "number" },
          "totalTenants": { "type": "integer" },
          "submittedTasks": { "type": "integer" },
          "maintenanceRequests": { "type": "integer" },
          "totalWithdrawn": { "type": "number" }
        }
      },
      "Payment": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "leaseId": { "type": "string" },
          "amount": { "type": "number" },
          "status": { "type": "string", "enum": ["Pending", "Paid", "Overdue", "Refunded"] },
          "receiptUrl": { "type": "string" },
          "transactionRef": { "type": "string" }
        }
      }
    },
    "securitySchemes": {
      "bearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      }
    }
  }
}
''';
