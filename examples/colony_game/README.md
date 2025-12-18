# Colony Game Example (this readme is 99% LLM-generated)

A turn-based colony management simulation built with the **GenUI** SDK and **Google Generative AI**. This example demonstrates how to build a complex, stateful application where an LLM acts as the "Game Master," managing events, interpreting user intent, and dynamically generating UI components. The leading feature here is that UIs can be generated to suit random events that happen in the game.

https://github.com/user-attachments/assets/1d4b55f4-2a5f-470c-bd03-d94c08ecd353

## Overview

In **Colony Game**, you simply act as the leader of a small settlement. You issue commands in natural language (e.g., "Build a farm here," "Send explorer to the north"), and the AI Game Master interprets these commands, updates the game state, and narrates the results.

### Key Features

*   **Natural Language Command Interface**: Interface with the game world entirely through conversation.
*   **Dynamic Event Generation**: The AI generates random daily events (e.g., "Merchant Arrival", "Storm", "Mystery Cave") using GenUI's `surfaceUpdate` tool.
*   **Interactive Decision Cards**: Events present choices (e.g., "Trade", "Ignore", "Investigate") that are rendered as interactive UI cards (`DecisionCard`) and handled by the game logic.
*   **Procedural World**: A tile-based map with resources, units, and structures.
*   **Turn-Based Loop**: A "Day" cycle where you plan actions, end the day, and review the AI-generated report of what happened.

## Architecture

This project showcases several advanced patterns for GenUI applications:

1.  **AI Game Master**: The `systemInstruction` in `game_page.dart` gives the LLM a specific persona ("Pragmatic Pioneer") and strict rules for managing the game loop.
2.  **Tool-Use Driven Logic**: The game logic (movement, building, resource gathering) is exposed to the AI via tools (`moveUnit`, `buildStructure`, `getResources`). The AI calls these tools in response to user commands.
3.  **Hybrid State Management**:
    *   **Deterministic State**: The `WorldState` class manages the "hard" game data (grid, unit positions, resources).
    *   **Generative Narrative**: The AI handles the "soft" layer—narrating outcomes, creating flavor text, and managing random events.
4.  **Custom Component Catalog**:
    *   `MapWidget`: A custom visualization of the game grid.
    *   `DecisionCard`: A flexible card for displaying events with choices.
    *   `ResourceDisplay`: A live-updating view of colony resources.

## Getting Started

### Prerequisites

*   Flutter SDK
*   A Google Gemini API Key

### Configuration

1.  **Get an API Key**: Obtain an API key from [Google AI Studio](https://aistudio.google.com/).
2.  **Set Environment Variable**:
    You must export your API key as an environment variable before running the app.

    ```bash
    export GEMINI_API_KEY=your_api_key_here
    ```

### Running the Game

Run the app using `flutter run`:

```bash
flutter run -d macos
```

*(Note: This example is optimized for macOS/Desktop, but can be adapted for mobile.)*

## How to Play

1.  **Start**: You begin with a few units (settlers) and basic resources.
2.  **Plan**: Tell the AI what you want to do.
    *   *"Unit 1, build a farm at 5, 5"*
    *   *"Everyone, move north"*
    *   *"How much wood do we have?"*
3.  **End Day**: When you are satisfied with your orders, click the **End Day** button (moon icon).
4.  **Events**: Review the daily report. If an event occurs (e.g., a merchant appears), make a choice using the dialog buttons.
5.  **Survive**: Try to keep your colony alive and growing for 30 days!
