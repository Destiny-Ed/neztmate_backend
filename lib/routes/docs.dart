final openApiSpec = r'''
{
  "openapi": "3.0.3",
  "info": {
    "title": "NeztMate Property Management API",
    "description": "Backend API for NeztMate — multi-tenant property ops (tenants, landowners, managers, artisans), partners, subscriptions, payments (Paystack), maintenance, community, and admin analytics. Nigeria-focused.",
    "version": "1.2.0",
    "contact": { "name": "NeztMate Support", "email": "support@neztmate.com" }
  },
  "servers": [
    { "url": "http://localhost:8080", "description": "Local" },
    { "url": "https://neztmate-backend.onrender.com", "description": "Staging / Render" },
    { "url": "https://api.neztmate.com", "description": "Production" }
  ],
  "tags": [
    { "name": "Auth" },
    { "name": "Users" },
    { "name": "Partners" },
    { "name": "Platform" },
    { "name": "Properties" },
    { "name": "Units" },
    { "name": "Applications" },
    { "name": "Leases" },
    { "name": "Maintenance" },
    { "name": "Tasks" },
    { "name": "Payments" },
    { "name": "Subscriptions" },
    { "name": "Affiliates" },
    { "name": "Invites" },
    { "name": "Messages" },
    { "name": "Notifications" },
    { "name": "Community" },
    { "name": "Reviews" },
    { "name": "History" },
    { "name": "Health" }
  ],
  "security": [{ "bearerAuth": [] }],
  "paths": {
    "/health": {
      "get": {
        "tags": ["Health"],
        "summary": "Health check",
        "security": [],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": { "type": "string" },
                    "message": { "type": "string" }
                  }
                }
              }
            }
          }
        }
      }
    },

    "/auth/register": {
      "post": {
        "tags": ["Auth"],
        "summary": "Register (email/password)",
        "security": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["email", "password", "fullName", "role", "fcmToken", "platform"],
                "properties": {
                  "email": { "type": "string", "format": "email" },
                  "password": { "type": "string", "minLength": 6 },
                  "fullName": { "type": "string" },
                  "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] },
                  "phone": { "type": "string" },
                  "partnerId": { "type": "string", "description": "Defaults to neztmate when omitted" },
                  "fcmToken": { "type": "string" },
                  "platform": { "type": "string", "enum": ["ios", "android", "web"] },
                  "country": { "type": "string" },
                  "referralCode": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Registered",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/AuthResponse" }
              }
            }
          },
          "400": { "description": "Invalid input" },
          "409": { "description": "Email already exists" }
        }
      }
    },
    "/auth/login": {
      "post": {
        "tags": ["Auth"],
        "summary": "Login",
        "security": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["email", "password", "fcmToken"],
                "properties": {
                  "email": { "type": "string" },
                  "password": { "type": "string" },
                  "partnerId": { "type": "string", "description": "Required for partner users; omit for platform_admin" },
                  "fcmToken": { "type": "string" },
                  "platform": { "type": "string" },
                  "loginAs": { "type": "string", "enum": ["platform_admin"], "description": "Platform admin login" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/AuthResponse" }
              }
            }
          },
          "401": { "description": "Invalid credentials" }
        }
      }
    },
    "/auth/social": {
      "post": {
        "tags": ["Auth"],
        "summary": "Social login (Firebase ID token)",
        "security": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["idToken", "role", "fcmToken"],
                "properties": {
                  "idToken": { "type": "string" },
                  "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] },
                  "fullName": { "type": "string" },
                  "partnerId": { "type": "string" },
                  "fcmToken": { "type": "string" },
                  "platform": { "type": "string" },
                  "country": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/AuthResponse" }
              }
            }
          },
          "400": { "description": "Invalid token or role" },
          "401": { "description": "Invalid or expired token" }
        }
      }
    },
    "/auth/refresh-token": {
      "post": {
        "tags": ["Auth"],
        "summary": "Refresh access token",
        "security": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["refreshToken"],
                "properties": { "refreshToken": { "type": "string" } }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "New tokens",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "accessToken": { "type": "string" },
                    "refreshToken": { "type": "string" }
                  }
                }
              }
            }
          },
          "401": { "description": "Invalid refresh token" }
        }
      }
    },
    "/auth/logout": {
      "post": {
        "tags": ["Auth"],
        "summary": "Logout / invalidate refresh token",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": { "refreshToken": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Logged out" } }
      }
    },

    "/users/me": {
      "get": {
        "tags": ["Users"],
        "summary": "Current user profile",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "user": { "$ref": "#/components/schemas/User" } }
                }
              }
            }
          },
          "401": { "description": "Unauthorized" }
        }
      },
      "patch": {
        "tags": ["Users"],
        "summary": "Update current user",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "fullName": { "type": "string" },
                  "phone": { "type": "string" },
                  "profilePhotoUrl": { "type": "string" },
                  "fcmToken": { "type": "string" },
                  "primarySkill": { "type": "string" },
                  "yearsExperience": { "type": "integer" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Updated" } }
      },
      "delete": {
        "tags": ["Users"],
        "summary": "Delete account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["confirm"],
                "properties": { "confirm": { "type": "boolean" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Deleted" } }
      }
    },
    "/users/stats": {
      "get": {
        "tags": ["Users"],
        "summary": "Role-based dashboard stats",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "stats": { "$ref": "#/components/schemas/UserStats" } }
                }
              }
            }
          }
        }
      }
    },
    "/users/switch-role": {
      "post": {
        "tags": ["Users"],
        "summary": "Switch active role (multi-role users)",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["role"],
                "properties": {
                  "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan"] }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Role switched" }, "400": { "description": "Role not available" } }
      }
    },
    "/users/{id}": {
      "get": {
        "tags": ["Users"],
        "summary": "Get user by id",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "user": { "$ref": "#/components/schemas/User" } }
                }
              }
            }
          },
          "404": { "description": "Not found" }
        }
      }
    },

    "/partners/config": {
      "get": {
        "tags": ["Partners"],
        "summary": "Public partner branding by slug",
        "security": [],
        "parameters": [
          { "name": "slug", "in": "query", "schema": { "type": "string", "default": "neztmate" } }
        ],
        "responses": {
          "200": {
            "description": "Branding payload",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "partner": { "$ref": "#/components/schemas/PartnerPublic" } }
                }
              }
            }
          },
          "403": { "description": "Partner inactive" },
          "404": { "description": "Not found" }
        }
      }
    },
    "/partners/public": {
      "get": {
        "tags": ["Partners"],
        "summary": "List active partners (public marketing)",
        "security": [],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "partners": {
                      "type": "array",
                      "items": { "$ref": "#/components/schemas/PartnerPublic" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/partners/requests": {
      "post": {
        "tags": ["Partners"],
        "summary": "Submit become-a-partner request",
        "security": [],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/PartnerRequestCreate" }
            }
          }
        },
        "responses": {
          "200": { "description": "Submitted" },
          "400": { "description": "Validation error" }
        }
      },
      "get": {
        "tags": ["Partners"],
        "summary": "List partner requests (platform admin)",
        "parameters": [
          { "name": "status", "in": "query", "schema": { "type": "string", "enum": ["pending", "contacted", "approved", "rejected"] } }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "requests": {
                      "type": "array",
                      "items": { "$ref": "#/components/schemas/PartnerRequest" }
                    }
                  }
                }
              }
            }
          },
          "403": { "description": "Platform admin only" }
        }
      }
    },
    "/partners/requests/{id}": {
      "patch": {
        "tags": ["Partners"],
        "summary": "Update partner request status (platform admin)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "status": { "type": "string", "enum": ["pending", "contacted", "approved", "rejected"] },
                  "notes": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Updated" }, "403": { "description": "Forbidden" } }
      }
    },
    "/partners/me": {
      "get": {
        "tags": ["Partners"],
        "summary": "Current partner workspace",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "partner": { "$ref": "#/components/schemas/Partner" } }
                }
              }
            }
          }
        }
      },
      "patch": {
        "tags": ["Partners"],
        "summary": "Update partner settings",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "supportEmail": { "type": "string" },
                  "supportPhone": { "type": "string" },
                  "website": { "type": "string" },
                  "domain": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Updated" } }
      }
    },
    "/partners/me/branding": {
      "patch": {
        "tags": ["Partners"],
        "summary": "Update partner branding (app + web)",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "name": { "type": "string" },
                  "tagline": { "type": "string" },
                  "primaryColor": { "type": "string", "example": "#0d9488" },
                  "secondaryColor": { "type": "string" },
                  "logoUrl": { "type": "string" },
                  "supportEmail": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Branding updated" }, "400": { "description": "Invalid color" } }
      }
    },
    "/partners/me/analytics": {
      "get": {
        "tags": ["Partners"],
        "summary": "Partner workspace analytics",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/PartnerAnalytics" }
              }
            }
          }
        }
      }
    },
    "/partners/me/notifications": {
      "get": {
        "tags": ["Partners"],
        "summary": "Partner admin notifications",
        "parameters": [{ "name": "limit", "in": "query", "schema": { "type": "integer", "default": 30 } }],
        "responses": { "200": { "description": "OK" } }
      },
      "post": {
        "tags": ["Partners"],
        "summary": "Create partner notification",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["title", "body"],
                "properties": {
                  "title": { "type": "string" },
                  "body": { "type": "string" },
                  "type": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/partners": {
      "get": {
        "tags": ["Partners"],
        "summary": "List partners (platform admin)",
        "parameters": [
          { "name": "activeOnly", "in": "query", "schema": { "type": "boolean" } }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "partners": { "type": "array", "items": { "$ref": "#/components/schemas/Partner" } }
                  }
                }
              }
            }
          },
          "403": { "description": "Platform admin only" }
        }
      },
      "post": {
        "tags": ["Partners"],
        "summary": "Create partner (platform admin)",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["slug", "name"],
                "properties": {
                  "slug": { "type": "string", "pattern": "^[a-z0-9-]{3,40}$" },
                  "name": { "type": "string" },
                  "tagline": { "type": "string" },
                  "primaryColor": { "type": "string" },
                  "secondaryColor": { "type": "string" },
                  "logoUrl": { "type": "string" },
                  "supportEmail": { "type": "string" },
                  "isActive": { "type": "boolean" },
                  "features": { "type": "object" },
                  "fees": { "type": "object" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Created" }, "400": { "description": "Validation" }, "403": { "description": "Forbidden" } }
      }
    },
    "/partners/{id}": {
      "get": {
        "tags": ["Partners"],
        "summary": "Get partner by id",
        "security": [],
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" }, "404": { "description": "Not found" } }
      },
      "patch": {
        "tags": ["Partners"],
        "summary": "Update partner (platform admin)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "type": "object", "additionalProperties": true }
            }
          }
        },
        "responses": { "200": { "description": "Updated" }, "403": { "description": "Forbidden" } }
      }
    },
    "/partners/{id}/status": {
      "patch": {
        "tags": ["Partners"],
        "summary": "Activate/deactivate partner",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "isActive": { "type": "boolean" },
                  "status": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "OK" }, "403": { "description": "Forbidden" } }
      }
    },

    "/platform/analytics": {
      "get": {
        "tags": ["Platform"],
        "summary": "Platform-wide analytics",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/PlatformAnalytics" }
              }
            }
          },
          "403": { "description": "Platform admin only" }
        }
      }
    },

    "/properties": {
      "get": {
        "tags": ["Properties"],
        "summary": "My properties (landowner/manager) with tenant summaries",
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "properties": { "type": "array", "items": { "$ref": "#/components/schemas/Property" } }
                  }
                }
              }
            }
          }
        }
      },
      "post": {
        "tags": ["Properties"],
        "summary": "Create property",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/PropertyCreate" }
            }
          }
        },
        "responses": { "200": { "description": "Created" }, "400": { "description": "Validation" } }
      }
    },
    "/properties/{id}": {
      "get": {
        "tags": ["Properties"],
        "summary": "Property detail + tenants + staff",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" }, "404": { "description": "Not found" } }
      },
      "patch": {
        "tags": ["Properties"],
        "summary": "Update property",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/PropertyCreate" }
            }
          }
        },
        "responses": { "200": { "description": "Updated" } }
      },
      "delete": {
        "tags": ["Properties"],
        "summary": "Delete property",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Deleted" } }
      }
    },
    "/properties/{id}/tenants": {
      "get": {
        "tags": ["Properties"],
        "summary": "Tenants by property (current + past)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },

    "/units": {
      "post": {
        "tags": ["Units"],
        "summary": "Create unit",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/Unit" }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/units/available": {
      "get": {
        "tags": ["Units"],
        "summary": "Listed vacant units for tenants",
        "responses": { "200": { "description": "Units + property info" } }
      }
    },
    "/units/my": {
      "get": {
        "tags": ["Units"],
        "summary": "My units with occupants (owner/manager)",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/units/property/{propertyId}": {
      "get": {
        "tags": ["Units"],
        "summary": "Units by property",
        "parameters": [{ "name": "propertyId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/units/{id}": {
      "get": {
        "tags": ["Units"],
        "summary": "Unit detail",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" }, "404": { "description": "Not found" } }
      },
      "patch": {
        "tags": ["Units"],
        "summary": "Update unit",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Updated" }, "400": { "description": "Invalid" } }
      },
      "delete": {
        "tags": ["Units"],
        "summary": "Delete unit",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Deleted" } }
      }
    },
    "/units/{id}/list": {
      "post": {
        "tags": ["Units"],
        "summary": "List unit for rent (vacant / rent due only)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Listed" }, "400": { "description": "Not listable" } }
      }
    },
    "/units/{id}/unlist": {
      "post": {
        "tags": ["Units"],
        "summary": "Unlist unit for rent",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Unlisted" } }
      }
    },
    "/units/{id}/like": {
      "post": {
        "tags": ["Units"],
        "summary": "Like unit",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/units/{id}/comments": {
      "get": {
        "tags": ["Units"],
        "summary": "List unit comments",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      },
      "post": {
        "tags": ["Units"],
        "summary": "Add unit comment",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["content"],
                "properties": { "content": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },

    "/applications": {
      "post": {
        "tags": ["Applications"],
        "summary": "Submit lease application (tenant)",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["unitId", "propertyId", "screeningData"],
                "properties": {
                  "unitId": { "type": "string" },
                  "propertyId": { "type": "string" },
                  "landownerId": { "type": "string" },
                  "message": { "type": "string" },
                  "proposedRent": { "type": "number" },
                  "desiredStartDate": { "type": "string", "format": "date-time" },
                  "documents": { "type": "array", "items": { "type": "string" } },
                  "screeningData": { "type": "object" },
                  "referralCode": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": { "description": "Submitted (may include paymentUrl if application fee)" },
          "400": { "description": "Validation / duplicate" },
          "403": { "description": "Tenants only" }
        }
      }
    },
    "/applications/me": {
      "get": {
        "tags": ["Applications"],
        "summary": "My applications (tenant) or inbound (owner/manager)",
        "responses": { "200": { "description": "Enriched applications" } }
      }
    },
    "/applications/unit/{unitId}": {
      "get": {
        "tags": ["Applications"],
        "summary": "Applications for a unit",
        "parameters": [{ "name": "unitId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/applications/{id}": {
      "get": {
        "tags": ["Applications"],
        "summary": "Application detail (enriched tenant reputation)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" }, "403": { "description": "Forbidden" }, "404": { "description": "Not found" } }
      }
    },
    "/applications/{id}/approve": {
      "patch": {
        "tags": ["Applications"],
        "summary": "Approve application → creates lease draft",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Approved" } }
      }
    },
    "/applications/{id}/reject": {
      "patch": {
        "tags": ["Applications"],
        "summary": "Reject application",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": { "reason": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Rejected" } }
      }
    },
    "/applications/{id}/withdraw": {
      "patch": {
        "tags": ["Applications"],
        "summary": "Tenant withdraws application",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Withdrawn" } }
      }
    },
    "/applications/{id}/pay-fee": {
      "post": {
        "tags": ["Applications"],
        "summary": "Initialize application fee when status is feePending",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Payment URL" } }
      }
    },

    "/leases/me": {
      "get": {
        "tags": ["Leases"],
        "summary": "My leases (tenant active)",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/leases/landowner": {
      "get": {
        "tags": ["Leases"],
        "summary": "Leases for landowner",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/leases/unit/{unitId}": {
      "get": {
        "tags": ["Leases"],
        "summary": "Leases by unit",
        "parameters": [{ "name": "unitId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/leases/{id}": {
      "get": {
        "tags": ["Leases"],
        "summary": "Lease detail (enriched)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" }, "403": { "description": "Forbidden" }, "404": { "description": "Not found" } }
      }
    },
    "/leases/{id}/sign": {
      "post": {
        "tags": ["Leases"],
        "summary": "Tenant signs lease → Pending Payment",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["signedPdfUrl"],
                "properties": { "signedPdfUrl": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Signed" } }
      }
    },
    "/leases/{id}/confirm-payment": {
      "patch": {
        "tags": ["Leases"],
        "summary": "Owner confirms offline payment → Active + occupancy",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "amount": { "type": "number" },
                  "method": { "type": "string" },
                  "note": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Activated" } }
      }
    },
    "/leases/{id}/status": {
      "patch": {
        "tags": ["Leases"],
        "summary": "Update lease status (e.g. pending payment after expiry)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["status"],
                "properties": {
                  "status": {
                    "type": "string",
                    "enum": ["Active", "Inactive", "Pending Payment", "Terminated", "Pending Signature"]
                  }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Updated" }, "400": { "description": "Invalid transition" } }
      }
    },
    "/leases/{id}/terminate": {
      "post": {
        "tags": ["Leases"],
        "summary": "Terminate lease",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": { "reason": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Terminated" } }
      }
    },
    "/leases/{id}/transfer": {
      "post": {
        "tags": ["Leases"],
        "summary": "Request lease transfer to new tenant",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["newTenantId"],
                "properties": {
                  "newTenantId": { "type": "string" },
                  "message": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Transfer requested" } }
      }
    },
    "/leases/transfers/{id}/approve": {
      "patch": {
        "tags": ["Leases"],
        "summary": "Approve lease transfer",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Approved" } }
      }
    },
    "/leases/transfers/{id}/reject": {
      "patch": {
        "tags": ["Leases"],
        "summary": "Reject lease transfer",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Rejected" } }
      }
    },

    "/maintenance": {
      "post": {
        "tags": ["Maintenance"],
        "summary": "Create maintenance request (tenant)",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["unitId", "description"],
                "properties": {
                  "unitId": { "type": "string" },
                  "propertyId": { "type": "string" },
                  "description": { "type": "string" },
                  "priority": { "type": "string", "enum": ["Low", "Medium", "High", "Emergency"] },
                  "photoUrls": { "type": "array", "items": { "type": "string" } }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/maintenance/my": {
      "get": {
        "tags": ["Maintenance"],
        "summary": "My maintenance requests",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/maintenance/managed": {
      "get": {
        "tags": ["Maintenance"],
        "summary": "All requests across managed properties",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/maintenance/{id}": {
      "get": {
        "tags": ["Maintenance"],
        "summary": "Request detail",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/maintenance/{id}/assign": {
      "patch": {
        "tags": ["Maintenance"],
        "summary": "Assign to artisan",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["artisanId"],
                "properties": { "artisanId": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "Assigned" } }
      }
    },

    "/tasks": {
      "post": {
        "tags": ["Tasks"],
        "summary": "Create task from maintenance",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/Task" }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/tasks/my": {
      "get": {
        "tags": ["Tasks"],
        "summary": "Tasks for current user (artisan/manager)",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/tasks/{id}": {
      "get": {
        "tags": ["Tasks"],
        "summary": "Task detail",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/tasks/{id}/accept": {
      "patch": {
        "tags": ["Tasks"],
        "summary": "Artisan accepts task",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Accepted" } }
      }
    },
    "/tasks/{id}/decline": {
      "patch": {
        "tags": ["Tasks"],
        "summary": "Artisan declines task",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Declined" } }
      }
    },
    "/tasks/{id}/complete": {
      "patch": {
        "tags": ["Tasks"],
        "summary": "Complete task with summary/cost",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "summary": { "type": "string" },
                  "cost": { "type": "number" },
                  "photoUrls": { "type": "array", "items": { "type": "string" } }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Completed" } }
      }
    },
    "/tasks/{id}/approve-payment": {
      "post": {
        "tags": ["Tasks"],
        "summary": "Approve artisan payment (wallet / link / external)",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["method"],
                "properties": {
                  "method": { "type": "string", "enum": ["wallet", "link", "external"] },
                  "amount": { "type": "number" },
                  "propertyId": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Payment approved / link returned" } }
      }
    },

    "/payments/initialize_payment": {
      "post": {
        "tags": ["Payments"],
        "summary": "Initialize Paystack payment (rent, renewal, fee, etc.)",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["amount", "email"],
                "properties": {
                  "leaseId": { "type": "string" },
                  "taskId": { "type": "string" },
                  "amount": { "type": "number" },
                  "email": { "type": "string" },
                  "type": {
                    "type": "string",
                    "enum": ["rent", "rent-renewal", "application_fee", "subscription", "task"]
                  },
                  "propertyId": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "authorization_url": { "type": "string" },
                    "reference": { "type": "string" },
                    "access_code": { "type": "string" }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/payments/my_payments": {
      "get": {
        "tags": ["Payments"],
        "summary": "My payments",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/payments/summary": {
      "get": {
        "tags": ["Payments"],
        "summary": "Payment summary for user/property",
        "parameters": [
          { "name": "propertyId", "in": "query", "schema": { "type": "string" } },
          { "name": "leaseId", "in": "query", "schema": { "type": "string" } }
        ],
        "responses": {
          "200": {
            "description": "OK",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": { "summary": { "$ref": "#/components/schemas/PaymentSummary" } }
                }
              }
            }
          }
        }
      }
    },
    "/payments/lease/{leaseId}": {
      "get": {
        "tags": ["Payments"],
        "summary": "Payments by lease",
        "parameters": [{ "name": "leaseId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/payments/record_payment": {
      "post": {
        "tags": ["Payments"],
        "summary": "Record offline payment",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/Payment" }
            }
          }
        },
        "responses": { "200": { "description": "Recorded" } }
      }
    },
    "/payments/{id}/mark_paid": {
      "patch": {
        "tags": ["Payments"],
        "summary": "Mark payment paid",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/payments/webhook": {
      "post": {
        "tags": ["Payments"],
        "summary": "Paystack webhook (public)",
        "security": [],
        "responses": { "200": { "description": "Received" }, "400": { "description": "Invalid signature" } }
      }
    },
    "/payments/withdrawals": {
      "post": {
        "tags": ["Payments"],
        "summary": "Request withdrawal",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["amount", "propertyId"],
                "properties": {
                  "amount": { "type": "number" },
                  "propertyId": { "type": "string" },
                  "method": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Submitted" }, "400": { "description": "No payout account / insufficient balance" } }
      }
    },
    "/payments/withdrawals/me": {
      "get": {
        "tags": ["Payments"],
        "summary": "My withdrawals",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/payments/payout-accounts": {
      "get": {
        "tags": ["Payments"],
        "summary": "List payout accounts",
        "responses": { "200": { "description": "OK" } }
      },
      "post": {
        "tags": ["Payments"],
        "summary": "Save payout account",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["bankName", "accountNumber", "accountName", "bankCode"],
                "properties": {
                  "bankName": { "type": "string" },
                  "accountNumber": { "type": "string" },
                  "accountName": { "type": "string" },
                  "bankCode": { "type": "string" },
                  "propertyId": { "type": "string" },
                  "isDefault": { "type": "boolean" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Saved" } }
      }
    },
    "/payments/payout-accounts/{id}": {
      "delete": {
        "tags": ["Payments"],
        "summary": "Remove payout account",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Removed" } }
      }
    },
    "/payments/payout-accounts/{id}/default": {
      "patch": {
        "tags": ["Payments"],
        "summary": "Set default payout account",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/payments/banks": {
      "get": {
        "tags": ["Payments"],
        "summary": "List Nigerian banks (Paystack)",
        "responses": { "200": { "description": "Bank list" } }
      }
    },
    "/payments/resolve-account": {
      "get": {
        "tags": ["Payments"],
        "summary": "Resolve bank account name",
        "parameters": [
          { "name": "account_number", "in": "query", "required": true, "schema": { "type": "string" } },
          { "name": "bank_code", "in": "query", "required": true, "schema": { "type": "string" } }
        ],
        "responses": { "200": { "description": "Resolved" } }
      }
    },

    "/subscriptions/plans": {
      "get": {
        "tags": ["Subscriptions"],
        "summary": "List plans for partner",
        "responses": { "200": { "description": "OK" } }
      },
      "post": {
        "tags": ["Subscriptions"],
        "summary": "Create plan (admin)",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/SubscriptionPlan" }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/subscriptions/plans/{id}": {
      "patch": {
        "tags": ["Subscriptions"],
        "summary": "Update plan",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Updated" } }
      }
    },
    "/subscriptions/me": {
      "get": {
        "tags": ["Subscriptions"],
        "summary": "Current user subscription",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/subscriptions/subscribe": {
      "post": {
        "tags": ["Subscriptions"],
        "summary": "Subscribe to plan",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["planId"],
                "properties": {
                  "planId": { "type": "string" },
                  "billingCycle": { "type": "string", "enum": ["monthly", "yearly"] }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Activated or payment required" } }
      }
    },
    "/subscriptions/cancel": {
      "post": {
        "tags": ["Subscriptions"],
        "summary": "Cancel with grace until endDate",
        "responses": { "200": { "description": "Cancelled" } }
      }
    },

    "/affiliates/stats": {
      "get": {
        "tags": ["Affiliates"],
        "summary": "My referral stats",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/affiliates/link": {
      "get": {
        "tags": ["Affiliates"],
        "summary": "Get referral link for unit/property",
        "parameters": [
          { "name": "unitId", "in": "query", "schema": { "type": "string" } },
          { "name": "propertyId", "in": "query", "schema": { "type": "string" } }
        ],
        "responses": { "200": { "description": "Link + code" } }
      }
    },
    "/affiliates/payouts": {
      "get": {
        "tags": ["Affiliates"],
        "summary": "Payout history",
        "responses": { "200": { "description": "OK" } }
      },
      "post": {
        "tags": ["Affiliates"],
        "summary": "Request affiliate payout",
        "responses": { "200": { "description": "Requested" } }
      }
    },

    "/invites": {
      "post": {
        "tags": ["Invites"],
        "summary": "Send manager/artisan invite",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["inviteeEmail", "inviteeRole", "propertyIds", "message"],
                "properties": {
                  "inviteeEmail": { "type": "string" },
                  "inviteeRole": { "type": "string", "enum": ["Manager", "Artisan"] },
                  "propertyIds": { "type": "array", "items": { "type": "string" } },
                  "message": { "type": "string" },
                  "inviteePhone": { "type": "string" }
                }
              }
            }
          }
        },
        "responses": { "200": { "description": "Sent (expires 5 days)" } }
      },
      "get": {
        "tags": ["Invites"],
        "summary": "My invites (sent or received)",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/invites/{id}": {
      "get": {
        "tags": ["Invites"],
        "summary": "Get invite by id",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/invites/{id}/accept": {
      "post": {
        "tags": ["Invites"],
        "summary": "Accept invite → assign to properties",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "Accepted" }, "400": { "description": "Expired" } }
      }
    },

    "/messages/chats": {
      "get": {
        "tags": ["Messages"],
        "summary": "Chat inbox",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/messages/conversation/{receiverId}": {
      "get": {
        "tags": ["Messages"],
        "summary": "Conversation thread",
        "parameters": [
          { "name": "receiverId", "in": "path", "required": true, "schema": { "type": "string" } },
          { "name": "propertyId", "in": "query", "schema": { "type": "string" } }
        ],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/messages": {
      "post": {
        "tags": ["Messages"],
        "summary": "Send message",
        "requestBody": {
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
        "responses": { "200": { "description": "Sent" } }
      }
    },
    "/messages/{id}/read": {
      "patch": {
        "tags": ["Messages"],
        "summary": "Mark message read",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/ws": {
      "get": {
        "tags": ["Messages"],
        "summary": "WebSocket upgrade for realtime chat",
        "description": "Connect with ?token=JWT. Client sends JSON {type:auth|send|ping}.",
        "security": [],
        "responses": { "101": { "description": "Switching Protocols" } }
      }
    },

    "/notifications": {
      "get": {
        "tags": ["Notifications"],
        "summary": "My notifications",
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/notifications/{id}/read": {
      "patch": {
        "tags": ["Notifications"],
        "summary": "Mark one read",
        "parameters": [{ "name": "id", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/notifications/read-all": {
      "patch": {
        "tags": ["Notifications"],
        "summary": "Mark all read",
        "responses": { "200": { "description": "OK" } }
      }
    },

    "/community/posts": {
      "post": {
        "tags": ["Community"],
        "summary": "Create post",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/CommunityPost" }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/community/posts/property/{propertyId}": {
      "get": {
        "tags": ["Community"],
        "summary": "Posts for property",
        "parameters": [{ "name": "propertyId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/community/posts/{postId}/comments": {
      "post": {
        "tags": ["Community"],
        "summary": "Comment on post",
        "parameters": [{ "name": "postId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["content"],
                "properties": { "content": { "type": "string" } }
              }
            }
          }
        },
        "responses": { "200": { "description": "OK" } }
      }
    },

    "/reviews": {
      "post": {
        "tags": ["Reviews"],
        "summary": "Create user review",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/UserReview" }
            }
          }
        },
        "responses": { "200": { "description": "Created" } }
      }
    },
    "/reviews/user/{userId}": {
      "get": {
        "tags": ["Reviews"],
        "summary": "Reviews for user",
        "parameters": [{ "name": "userId", "in": "path", "required": true, "schema": { "type": "string" } }],
        "responses": { "200": { "description": "OK" } }
      }
    },
    "/reviews/entity/{entityId}": {
      "get": {
        "tags": ["Reviews"],
        "summary": "Reviews by entity (e.g. property id)",
        "parameters": [
          { "name": "entityId", "in": "path", "required": true, "schema": { "type": "string" } },
          { "name": "type", "in": "query", "schema": { "type": "string" } }
        ],
        "responses": { "200": { "description": "OK" } }
      }
    },

    "/history/me": {
      "get": {
        "tags": ["History"],
        "summary": "My activity history",
        "parameters": [
          { "name": "limit", "in": "query", "schema": { "type": "integer", "default": 30 } }
        ],
        "responses": { "200": { "description": "OK" } }
      }
    }
  },
  "components": {
    "securitySchemes": {
      "bearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT"
      }
    },
    "schemas": {
      "AuthResponse": {
        "type": "object",
        "properties": {
          "accessToken": { "type": "string" },
          "refreshToken": { "type": "string" },
          "message": { "type": "string" },
          "user": { "$ref": "#/components/schemas/User" }
        }
      },
      "User": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "email": { "type": "string" },
          "fullName": { "type": "string" },
          "role": { "type": "string", "enum": ["Tenant", "Landowner", "Manager", "Artisan", "platform_admin"] },
          "roles": { "type": "array", "items": { "type": "string" } },
          "phone": { "type": "string" },
          "profilePhotoUrl": { "type": "string" },
          "verifiedIdentity": { "type": "boolean" },
          "verifiedEmployment": { "type": "boolean" },
          "rating": { "type": "number" },
          "reputationScore": { "type": "number" },
          "onTimePaymentRate": { "type": "number" },
          "partnerId": { "type": "string" },
          "referralCode": { "type": "string" },
          "createdAt": { "type": "string", "format": "date-time" },
          "lastLogin": { "type": "string", "format": "date-time" }
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
          "totalWithdrawn": { "type": "number" },
          "completedTasks": { "type": "integer" },
          "commissionEarned": { "type": "number" }
        }
      },
      "PartnerPublic": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "slug": { "type": "string" },
          "name": { "type": "string" },
          "tagline": { "type": "string" },
          "logoUrl": { "type": "string" },
          "primaryColor": { "type": "string" },
          "secondaryColor": { "type": "string" },
          "supportEmail": { "type": "string" },
          "features": { "type": "object" },
          "isActive": { "type": "boolean" }
        }
      },
      "Partner": {
        "allOf": [
          { "$ref": "#/components/schemas/PartnerPublic" },
          {
            "type": "object",
            "properties": {
              "supportPhone": { "type": "string" },
              "website": { "type": "string" },
              "domain": { "type": "string" },
              "fees": { "type": "object" },
              "createdAt": { "type": "string", "format": "date-time" },
              "updatedAt": { "type": "string", "format": "date-time" }
            }
          }
        ]
      },
      "PartnerRequestCreate": {
        "type": "object",
        "required": ["companyName", "contactName", "email", "phone", "proposedSlug", "cities", "message"],
        "properties": {
          "companyName": { "type": "string" },
          "contactName": { "type": "string" },
          "email": { "type": "string" },
          "phone": { "type": "string" },
          "proposedSlug": { "type": "string" },
          "website": { "type": "string" },
          "cities": { "type": "string" },
          "portfolioSize": { "type": "string" },
          "message": { "type": "string" }
        }
      },
      "PartnerRequest": {
        "allOf": [
          { "$ref": "#/components/schemas/PartnerRequestCreate" },
          {
            "type": "object",
            "properties": {
              "id": { "type": "string" },
              "status": { "type": "string" },
              "notes": { "type": "string" },
              "createdAt": { "type": "string", "format": "date-time" }
            }
          }
        ]
      },
      "PartnerAnalytics": {
        "type": "object",
        "properties": {
          "totalProperties": { "type": "integer" },
          "totalUnits": { "type": "integer" },
          "activeLeases": { "type": "integer" },
          "pendingApplications": { "type": "integer" },
          "openMaintenance": { "type": "integer" },
          "totalReceived": { "type": "number" },
          "totalWithdrawn": { "type": "number" },
          "withdrawableAmount": { "type": "number" },
          "activeSubscriptions": { "type": "integer" },
          "subscriptionPlan": { "type": "string" }
        }
      },
      "PlatformAnalytics": {
        "type": "object",
        "properties": {
          "totalPartners": { "type": "integer" },
          "activePartners": { "type": "integer" },
          "inactivePartners": { "type": "integer" },
          "pendingPartnerRequests": { "type": "integer" },
          "totalUsers": { "type": "integer" },
          "totalProperties": { "type": "integer" },
          "activeLeases": { "type": "integer" },
          "totalPaymentsVolume": { "type": "number" },
          "activeSubscriptions": { "type": "integer" },
          "pendingApplications": { "type": "integer" }
        }
      },
      "Property": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "name": { "type": "string" },
          "address": { "type": "string" },
          "type": { "type": "string" },
          "totalUnits": { "type": "integer" },
          "photoUrls": { "type": "array", "items": { "type": "string" } },
          "proofOfOwnershipUrl": { "type": "string" },
          "landownerId": { "type": "string" },
          "managerId": { "type": "string" },
          "partnerId": { "type": "string" },
          "amenities": { "type": "array", "items": { "type": "string" } }
        }
      },
      "PropertyCreate": {
        "type": "object",
        "required": ["name", "address", "photoUrls", "totalUnits"],
        "properties": {
          "name": { "type": "string" },
          "address": { "type": "string" },
          "type": { "type": "string" },
          "totalUnits": { "type": "integer" },
          "photoUrls": { "type": "array", "items": { "type": "string" } },
          "proofOfOwnershipUrl": { "type": "string" },
          "amenities": { "type": "array", "items": { "type": "string" } }
        }
      },
      "Unit": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "propertyId": { "type": "string" },
          "unitNumber": { "type": "string" },
          "yearlyRent": { "type": "number" },
          "bedrooms": { "type": "integer" },
          "bathrooms": { "type": "number" },
          "status": { "type": "string" },
          "isListedForRent": { "type": "boolean" },
          "currentTenantId": { "type": "string" },
          "likes": { "type": "integer" },
          "commentsCount": { "type": "integer" },
          "photoUrls": { "type": "array", "items": { "type": "string" } },
          "fees": { "type": "array", "items": { "type": "object" } },
          "partnerId": { "type": "string" }
        }
      },
      "Payment": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "leaseId": { "type": "string" },
          "amount": { "type": "number" },
          "status": { "type": "string" },
          "type": { "type": "string" },
          "transactionRef": { "type": "string" },
          "receiptUrl": { "type": "string" },
          "partnerId": { "type": "string" }
        }
      },
      "PaymentSummary": {
        "type": "object",
        "properties": {
          "totalReceived": { "type": "number" },
          "totalPaid": { "type": "number" },
          "totalWithdrawn": { "type": "number" },
          "balance": { "type": "number" },
          "withdrawableAmount": { "type": "number" },
          "pendingPayments": { "type": "integer" },
          "totalTransactions": { "type": "integer" }
        }
      },
      "SubscriptionPlan": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "name": { "type": "string" },
          "monthlyPrice": { "type": "number" },
          "yearlyPrice": { "type": "number" },
          "maxListings": { "type": "integer" },
          "partnerId": { "type": "string" },
          "isActive": { "type": "boolean" }
        }
      },
      "Task": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "requestId": { "type": "string" },
          "artisanId": { "type": "string" },
          "status": { "type": "string" },
          "cost": { "type": "number" },
          "summary": { "type": "string" },
          "assignedAt": { "type": "string", "format": "date-time" },
          "assignedBy": { "type": "string" }
        }
      },
      "CommunityPost": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "propertyId": { "type": "string" },
          "authorId": { "type": "string" },
          "content": { "type": "string" },
          "createdAt": { "type": "string", "format": "date-time" }
        }
      },
      "UserReview": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "reviewerId": { "type": "string" },
          "reviewedUserId": { "type": "string" },
          "reviewType": { "type": "string" },
          "rating": { "type": "number" },
          "comment": { "type": "string" },
          "tags": { "type": "array", "items": { "type": "string" } },
          "relatedLeaseId": { "type": "string" },
          "relatedTaskId": { "type": "string" }
        }
      }
    }
  }
}
''';
