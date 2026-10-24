# PedalBeat

**PedalBeat** is a sound-controlled interactive cycling game developed for the *Music and Multimedia Streaming over the Internet* course project at Politecnico di Torino.

The player controls the bicycle using sound gestures instead of a keyboard or controller:

- **Finger snap** → accelerate / pedal
- **Clap** → jump
- **No snap input** → bicycle gradually slows down due to friction

The project combines real-time audio sensing, feature extraction, machine learning, OSC communication, interactive visual rendering, and live browser streaming.

---

## Project Concept

The artistic idea behind PedalBeat is to transform **human rhythm into virtual physical effort**.

Repeated snaps simulate pedaling and increase bicycle speed. A clap represents a stronger physical gesture and makes the cyclist jump over obstacles.

The interaction is therefore:

```text
human gesture
→ sound
→ audio analysis
→ machine-learning classification
→ virtual physical action
```

---

## System Architecture

```text
Human Input
Snap / Clap
    |
    v
Microphone
    |
    v
PedalBeat Sensing
Processing
- onset detection
- 160 ms event capture
- FFT analysis
- amplitude analysis
    |
    | OSC /wek/inputs
    | 18 features
    | port 6448
    v
Wekinator
2-class classifier
1 = Snap
2 = Clap
    |
    | OSC /wek/outputs
    | port 12000
    v
PedalBeat Game
Processing
- Snap → acceleration
- Clap → jump
    |
    v
Visual Rendering
    |
    v
OBS Studio
    |
    | RTMP
    v
MediaMTX
    |
    v
Web Browser
```

The sensing process also sends:

```text
/pedalbeat/event
port 12000
```

directly to the game whenever a valid sound event is detected. The game only accepts the next Wekinator classification when such an event is pending.

For a single-member project, all software entities can run as independent processes on the same computer using localhost.

---

## Repository Structure

Recommended repository layout:

```text
PedalBeat/
├── PedalBeat_Sensing/
│   └── PedalBeat_Sensing.pde
│
├── PedalBeat_Game/
│   └── PedalBeat_Game.pde
│
├── Wekinator/
│   └── saved Wekinator project files
│
├── docs/
│   └── architecture.png
│
└── README.md
```

---

## 1. Sensing

The sensing component is implemented in **Processing**.

The microphone is monitored continuously, but the machine-learning classifier is not fed continuously.

Instead, PedalBeat first detects a relevant sound onset.

### Onset Detection

The current microphone amplitude is compared against a dynamic threshold based on the estimated background noise level.

A new sound event begins when the amplitude exceeds this threshold.

Current event parameters:

```text
minimum threshold: 0.025
threshold multiplier: 4.0
event duration: 160 ms
event cooldown: 280 ms
```

This design reduces false classifications caused by silence and background noise.

---

## 2. Audio Feature Extraction

When an event is detected, approximately **160 ms** of audio is captured and analyzed.

The sensing program calculates:

- a **64-bin FFT**
- 16 averaged spectral-band values
- average amplitude
- peak amplitude

The final feature vector therefore contains:

```text
16 spectral bands
+ 1 average amplitude
+ 1 peak amplitude
= 18 features
```

These 18 floating-point values are sent to Wekinator through OSC.

---

## 3. Machine Learning

**Wekinator** is used for real-time sound classification.

Configuration:

```text
Inputs: 18
Outputs: 1 classifier

Class 1 = SNAP
Class 2 = CLAP
```

OSC input:

```text
Address: /wek/inputs
Port: 6448
```

OSC output:

```text
Address: /wek/outputs
Port: 12000
```

The model is trained using multiple individual examples of snaps and claps with variations in strength and microphone distance.

The system uses only two ML classes. Silence/background noise is handled by the onset detector before classification.

This event-based approach proved more reliable than continuously classifying every audio frame.

---

## 4. OSC Communication

OSC is used for structural communication between the sensing, machine-learning, and rendering processes.

| Source | Destination | OSC Address | Port | Payload |
|---|---|---:|---:|---|
| Sensing | Wekinator | `/wek/inputs` | `6448` | 18 floating-point audio features |
| Sensing | Game | `/pedalbeat/event` | `12000` | Event identifier |
| Wekinator | Game | `/wek/outputs` | `12000` | Classifier output: 1 = Snap, 2 = Clap |

### Why `/pedalbeat/event` is used

Wekinator may produce output independently of a newly detected sound event.

To prevent stale or unrelated classifications from triggering actions, the game only accepts `/wek/outputs` when it is waiting for the classification of a valid detected event.

---

## 5. Rendering and Game Behaviour

The game is implemented in **Processing**.

### Snap

A recognized snap increases the bicycle speed.

Repeated snaps simulate repeated pedaling.

The speed is limited by a maximum value, while friction gradually decreases the speed when the player stops snapping.

### Clap

A recognized clap applies an upward velocity to the cyclist.

Gravity then brings the bicycle back to the road.

A jump is only accepted when the cyclist is currently on the ground.

### Obstacles

Obstacles periodically appear on the road.

- successfully passing an obstacle increases the score
- colliding with an obstacle ends the game
- pressing **Enter** restarts the game

### Visual Elements

The rendered scene includes:

- animated bicycle
- rotating wheels
- animated cyclist legs
- moving scenery
- road markings
- trees, hills and clouds
- obstacles
- current speed
- travelled distance
- number of obstacles passed
- on-screen Snap / Clap feedback
- game-over screen

---

## 6. Streaming

The rendered game output is captured and streamed using:

```text
Processing Game
→ OBS Studio
→ RTMP
→ MediaMTX
→ Web Browser
```

### OBS

OBS Studio captures the PedalBeat game window.

Streaming configuration:

```text
Service: Custom
Server: rtmp://localhost/mystream
Stream Key: empty
```

### MediaMTX

MediaMTX runs locally as the self-hosted media server.

Start MediaMTX before starting the OBS stream.

### Browser Client

The live stream can be opened in the browser at:

```text
http://localhost:8888/mystream
```

---

## Requirements

### Software

- Processing
- Wekinator
- OBS Studio
- MediaMTX
- Web browser

### Processing Libraries

Install the following Processing libraries:

- **Sound**
- **oscP5**
- **netP5**

---

## Wekinator Setup

Create or load the PedalBeat Wekinator project with:

```text
Input port: 6448
Input OSC address: /wek/inputs

Number of inputs: 18

Output type: classifier
Number of classes: 2

Class 1: SNAP
Class 2: CLAP

Output port: 12000
Output OSC address: /wek/outputs
```

Train the model using individual sound events.

A practical training set is approximately:

```text
40–60 snaps
40–60 claps
```

with some variation in loudness and microphone distance.

---

## Running the Project

Recommended startup order:

### 1. Start MediaMTX

Launch the MediaMTX executable and keep the terminal window open.

### 2. Start the PedalBeat Game

Open and run:

```text
PedalBeat_Game/PedalBeat_Game.pde
```

### 3. Start Wekinator

Open the saved PedalBeat project and click:

```text
Run
```

### 4. Start the Sensing Program

Open and run:

```text
PedalBeat_Sensing/PedalBeat_Sensing.pde
```

Confirm that microphone events are being detected.

### 5. Start OBS

Select the PedalBeat game window as the capture source.

Click:

```text
Start Streaming
```

### 6. Open the Browser Stream

Open:

```text
http://localhost:8888/mystream
```

The PedalBeat game should now be visible as a live stream.

---

## Controls

| Input | Action |
|---|---|
| Finger snap | Increase bicycle speed |
| Repeated snaps | Continue accelerating / simulate pedaling |
| Clap | Jump |
| No snap | Gradual slowdown |
| Enter | Restart after collision |

---

## Technologies Used

| Component | Technology |
|---|---|
| Audio sensing | Processing Sound |
| Feature extraction | Processing |
| OSC communication | oscP5 / netP5 |
| Machine learning | Wekinator |
| Visual rendering | Processing |
| Capture / broadcasting | OBS Studio |
| Streaming protocol | RTMP |
| Media server | MediaMTX |
| Client | Web browser |

---

## Design Notes

The first implementation used continuous classification with three classes:

```text
background
snap
clap
```

This caused unstable behaviour, including false jumps and false acceleration.

The system was redesigned so that:

1. Processing detects a relevant sound onset.
2. A short audio event is captured.
3. Event-level features are calculated.
4. Wekinator only distinguishes between Snap and Clap.

This separation between **event detection** and **sound classification** significantly improved interaction stability.

---

## Live Demo Flow

For a live demonstration:

1. Show the sensing window and trigger one sound event.
2. Explain the 18 extracted features.
3. Show Wekinator and the two classifier classes.
4. Demonstrate a snap increasing speed.
5. Demonstrate repeated snaps increasing speed further.
6. Stop snapping and show gradual slowdown.
7. Clap to jump over an obstacle.
8. Allow a collision to demonstrate game over.
9. Press Enter to restart.
10. Show the browser receiving the MediaMTX live stream.

---

## Project Summary

PedalBeat explores Human–Machine Interaction by replacing a conventional game controller with physical sound gestures.

A human action is captured through the microphone, transformed into an audio feature vector, classified with machine learning, transmitted using OSC, mapped to physical behaviour in a virtual cycling environment, and finally broadcast as a live web stream.

The complete interaction pipeline is:

```text
Human
→ Sound
→ Sensing
→ Feature Extraction
→ OSC
→ Machine Learning
→ OSC
→ Game Rendering
→ OBS
→ MediaMTX
→ Browser
```
