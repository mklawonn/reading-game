import { initializeApp } from "firebase-admin/app";

initializeApp();

// Story Builder — the LLM proxy for the story-building game.
export { storyBuilder } from "./storyBuilder";
