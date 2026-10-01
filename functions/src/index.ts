import { initializeApp } from "firebase-admin/app";

initializeApp();

export { ingestTelemetry } from "./ingestTelemetry";
export { ingestDriveImage } from "./ingestDriveImage";
