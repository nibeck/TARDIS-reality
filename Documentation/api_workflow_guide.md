# API Integration Workflow & Concepts

This guide explains the mental model for connecting your Python FastAPI server to your iOS Swift client using OpenAPI.

## The Mental Model

Think of the **OpenAPI Spec ([openapi.json](file:///Users/nibeck/Documents/Development/TARDIS-Reality/openapi.json))** as a legally binding **Contract** between your Server and your App.

| Concept | Analogy | In Python (Server) | In OpenAPI (Contract) | In Swift (Client) |
| :--- | :--- | :--- | :--- | :--- |
| **Path** | **The Action** (A button on a machine) | `@app.post("/api/led/fade")` | `paths: { "/api/led/fade": ... }` | `client.fade_api_led_fade_post()` |
| **Schema** | **The Form** (The data paperwork needed) | `class FadeRequest(BaseModel): ...` | `components: { schemas: { FadeRequest: ... } }` | `Components.Schemas.FadeRequest` |
| **Component** | ** The Library** (The filing cabinet) | The file where classes are defined | `components: { ... }` | `Components` enum namespace |

---

## 1. Components & Schemas
When you see `Components` and `Schemas`, think **"Data Types"**.

### In the Spec ([openapi.json](file:///Users/nibeck/Documents/Development/TARDIS-Reality/openapi.json))
The `components` section is just a storage locker for definitions so they don't have to be repeated.
*   **`schemas`**: The shape of your data objects (e.g., `Color`, `FadeRequest`).

### In Swift
The generator creates a `Components` enum to keep things organized so they don't clash with your own code.
*   **`Components.Schemas.Color`**: This is the Swift struct that matches your Python `Color` class.
*   **`Components.Schemas.FadeRequest`**: This is the Swift struct that matches your Python `FadeRequest` class.

**Example:**
If your Python server says:
```python
class FadeRequest(BaseModel):
    duration: float
```
Your Swift code will be:
```swift
let request = Components.Schemas.FadeRequest(duration: 5.0)
```

---

## 2. The Workflow (Adding Custom Endpoints)

Whenever you add a new feature, follow this loop:

### Step 1: Server (Python)
Define the data (Schema) and the function (Path).
```python
# 1. Define the Schema
class MyNewRequest(BaseModel):
    message: str

# 2. Define the Path
@app.post("/api/say-hello")
async def say_hello(body: MyNewRequest): ...
```

### Step 2: Contract (OpenAPI)
**Regenerate the contract.**
1.  Run your Python server.
2.  Go to `http://server-address:8000/openapi.json`.
3.  Download the JSON and **overwrite** [TARDIS-API/Sources/TARDISAPIClient/openapi.json](file:///Users/nibeck/Documents/Development/TARDIS-API/Sources/TARDISAPIClient/openapi.json).

### Step 3: Client (Swift)
**Build and Use.**
1.  **Build** your Xcode project. (This automatically re-reads the JSON and generates new Swift code).
2.  **Use it**:
    ```swift
    // The Input Data
    let input = Components.Schemas.MyNewRequest(message: "Hello!")
    
    // The Call
    try await client.say_hello_api_say_hello_post(body: .json(input))
    ```

## Why did we get the "Extra Argument" error?
Sometimes the translation isn't perfect.
*   **Python**: "This field can be a Color, or it can be None (null)." (`Union[Color, None]`)
*   **OpenAPI**: "This is `anyOf` [Color, null]."
*   **Swift Generator**: "I'm not sure how to make an initializer for 'anyOf' two things perfectly every time."

**The Fix**:
We simplified the contract. We told OpenAPI: "It's just a Color."
But we didn't mark it as **Required**.
So Swift said: "Okay, it's a `Color?` (Optional Color)."
This matched what we wanted!
