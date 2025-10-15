# nemois Local LLM Studio

**nemois Local LLM Studio** is a universal app for iOS and macOS designed for developers and advanced users. This application allows you to run AI models directly on your own devices and expose an OpenAI-compatible API on your local network. Since the entire process runs exclusively on your device, it ensures a high level of privacy and data security.

## ⚠️ Limitations

Since this app uses Apple's FoundationModel, it requires Apple Intelligence capatible device.

This app utilizes Apple's built-in Foundation Models. Currently, these models have a relatively small **4096-token context window**.

This limits the amount of conversation that can be processed at one time, making it less suitable for tasks that require understanding long contexts, such as summarizing lengthy documents. The app is primarily optimized for short and simple question-answering tasks.

## ⚠️ Development Notes
A significant portion of this project was developed with the assistance of Google's Gemini. This process also serves as an experiment to explore the possibilities of rapid prototyping and development leveraging AI.
Therefore, there may be various undiscovered bugs, and some features might not work as expected. Bug reports and feature suggestions are always welcome.

## ✨ Key Features

- **Universal App:** Flawlessly supports both iOS and macOS with a single codebase.
- **Local API Server:** A built-in lightweight web server (Vapor) provides an OpenAI-compatible `/v1/chat/completions` endpoint on your local network.
- **Built-in Foundation Model:** Instantly use the OS's built-in models through Apple's `FoundationModel` framework.
- **Real-time Resource Monitoring:** Check system resources like CPU and memory usage in real-time from the app's dashboard.
- **Modern UI with SwiftUI:** Built with SwiftUI for a smooth and responsive user experience.

## 🚀 Getting Started

### Prerequisites

- macOS
- [Xcode](https://developer.apple.com/xcode/)

### Setup and Run

1.  Open the `nemois_Worker.xcodeproj` file in Xcode. Xcode will automatically download the `Vapor` dependency.
2.  Build and run the app (`Cmd + R`).
3.  **Start the Server:**
    - Navigate to the `Dashboard` tab.
    - Turn on the toggle switch next to `Local API Server`.
    - Once the server starts successfully, the status will change to `Running`, and the local API address will be displayed.

## ⚙️ API Usage

Once the server is running, you can access the following endpoint from any device on your local network.

- **Endpoint:** `POST http://<your-local-ip-address>:8080/v1/chat/completions`
- **Header:** `Content-Type: application/json`

### cURL Example

```bash
curl [http://127.0.0.1:8080/v1/chat/completions](http://127.0.0.1:8080/v1/chat/completions) \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundation-model",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful assistant."
      },
      {
        "role": "user",
        "content": "Hello! Who are you?"
      }
    ]
  }'
```
  
## 🛠️ Key Technology Stack

- UI Framework: SwiftUI

- Web Server: Vapor

- AI Frameworks: FoundationModel

## 🙏 Acknowledgements

This project is made possible by the incredible work of several teams.

- Apple: For providing the powerful on-device Foundation Models through the GenerativeLanguage framework, enabling private and secure AI experiences.

- The Vapor Team: For creating Vapor, a robust and elegant web framework for Swift that powers the local API server.

- The Swift Team: For developing the Swift language and SwiftUI, which make building beautiful, native apps across platforms a joy.

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

Developed by nemois
