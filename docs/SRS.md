Excellent. Since a full IEEE SRS is long, I will deliver it in 3 structured parts as you requested.
This will follow the IEEE 830 Software Requirements Specification style used in real software engineering projects.

Structure we will follow:

PART 1
1. Introduction
2. Overall Description

PART 2
3. System Features (Functional Requirements)

PART 3
4. External Interface Requirements
5. Non-Functional Requirements
6. System Models
7. Other Requirements

***

# SOFTWARE REQUIREMENTS SPECIFICATION (SRS)

**GuardianNode**
Design and Implementation of an Emergency Alert Communication System for Cameroon
**Version:** 1.0
**Prepared For:** BTECH Project Implementation
**Prepared By:** Development Team

***

# PART 1 — INTRODUCTION AND OVERALL DESCRIPTION

***

## 1. INTRODUCTION

### 1.1 Purpose of the Document
This Software Requirements Specification (SRS) document describes the functional and non-functional requirements for GuardianNode, a mobile-based emergency alert communication system designed to improve emergency response time within communities across Cameroon.
The purpose of this document is to:
* Define the system requirements for GuardianNode
* Provide a reference for developers, project supervisors, and stakeholders
* Serve as a guideline for system implementation and testing

The SRS outlines the system's expected behavior, constraints, interfaces, and operational features.

***

### 1.2 Scope of the System
GuardianNode is a community-driven emergency alert platform that allows users to quickly notify nearby residents and authorities when they are in danger.
The system enables users to:
* Trigger an emergency alert using a mobile application
* Broadcast alerts to nearby registered users within a geographic radius
* Share real-time location information during emergencies
* Notify emergency contacts and police authorities
* Enable nearby residents to respond to emergencies

The system aims to reduce emergency response time and strengthen community safety across Cameroon.
GuardianNode will be implemented using:
* Flutter mobile framework
* Node.js backend services
* PostgreSQL database with geospatial support
* Firebase Cloud Messaging for push notifications
* SMS gateway integration for offline alert delivery

***

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Meaning |
|---|---|
| SOS | Emergency distress signal |
| GPS | Global Positioning System |
| Geo-Fence | Geographic boundary used for location filtering |
| FCM | Firebase Cloud Messaging |
| API | Application Programming Interface |
| Node | Registered community member in the system |
| Alert Radius | Distance within which emergency alerts are broadcast |

***

### 1.4 References
The following materials were used during the development of this specification:
* IEEE Software Engineering Standards
* Mobile Application Security Guidelines
* Google Maps API Documentation
* Firebase Cloud Messaging Documentation
* PostgreSQL PostGIS Documentation

***

### 1.5 Overview of the Document
This document is organized into the following sections:
* Section 1 — Introduction to the system
* Section 2 — Overall system description
* Section 3 — System functional requirements
* Section 4 — External interface requirements
* Section 5 — Non-functional requirements
* Section 6 — System models and diagrams

***

## 2. OVERALL DESCRIPTION

***

### 2.1 Product Perspective
GuardianNode is a standalone mobile emergency communication system that integrates with external communication services.
The system consists of:
1. Mobile Application (Flutter)
2. Backend Server (Node.js) // Note: Later sections mention Supabase Backend. Supabase API provides the backend server capabilities, but custom Node.js could be used as middleware.
3. Database System (PostgreSQL)
4. Notification Services (Firebase + SMS Gateway)
5. Administrative Web Dashboard

System Architecture Overview:
```text
Mobile Application
        │
        │
   API Gateway
        │
        │
Backend Server (Node.js/Supabase)
        │
        │
Database (PostgreSQL)
        │
        │
Communication Services
 ├ Firebase Cloud Messaging
 └ SMS Gateway
```

***

### 2.2 Product Functions
The GuardianNode system provides the following core functions:
* User registration and authentication
* GPS-based location detection
* Emergency alert triggering
* Emergency broadcast to nearby users
* Emergency category selection
* Response confirmation from nearby users
* Live location tracking during emergencies
* Police and emergency contact notification
* Community safety alerts
* Incident history logging
* Administrative monitoring of system activity

***

### 2.3 User Classes and Characteristics

**1. Community Users (Residents)**
* **Description:** Residents across Cameroon who install the mobile application.
* **Characteristics:** Basic smartphone users, limited technical knowledge, require simple and intuitive interfaces.
* **Responsibilities:** Trigger alerts during emergencies, respond to nearby incidents when possible.

**2. Emergency Responders (Neighbors)**
* **Description:** Nearby users who receive emergency alerts.
* **Capabilities:** View alert information, navigate to emergency locations, confirm response.

**3. Police Authorities**
* **Description:** Law enforcement officers who monitor incidents.
* **Capabilities:** Receive emergency alerts, view incident locations, track emergency cases.

**4. System Administrators**
* **Description:** Personnel responsible for managing the system.
* **Capabilities:** Monitor alerts, manage user accounts, configure system settings.

***

### 2.4 Operating Environment
The system will operate in the following environment:
* **Mobile Platform:** Android and iOS devices running Flutter application
* **Backend Platform:** Node.js server environment / Supabase API
* **Database:** PostgreSQL with PostGIS extension
* **External Services:** Firebase Cloud Messaging, SMS gateway provider, Google Maps API

***

### 2.5 Design and Implementation Constraints
The system must comply with the following constraints:
* Must operate under limited internet connectivity
* Must support mobile devices with moderate processing capabilities
* Must ensure user privacy and secure data transmission
* Must integrate third-party APIs for notifications and location services

***

### 2.6 Assumptions and Dependencies
The development of GuardianNode assumes:
* Users possess GPS-enabled smartphones
* Internet connectivity is available at least intermittently
* Emergency services are able to receive notifications from the system

Dependencies include:
* Firebase services
* SMS gateway service providers
* Google Maps API

***

# PART 2 — SYSTEM FEATURES & FUNCTIONAL REQUIREMENTS

***

## 3. SYSTEM FEATURES
This section describes the major functional capabilities of the GuardianNode system. Each feature is broken down into formal functional requirements.

***

### 3.1 Authentication Module
**Description:** The authentication module manages user registration, login, identity verification, and profile management. Authentication will be implemented using Supabase Auth.

**Functional Requirements:**
* **FR-1 User Registration:** The system shall allow new users to register using their mobile phone number. Registration must include Full name, Phone number, Residential quarter, Emergency contact. After registration, the system shall create a user account in the Supabase authentication system.
* **FR-2 OTP Verification:** The system shall send a One-Time Password (OTP) to the user's phone number for verification. The user must enter the OTP before the account is activated.
* **FR-3 Secure Login:** The system shall allow registered users to log in using their verified phone number and OTP authentication.
* **FR-4 User Profile Management:** The system shall allow users to update profile details, add or edit emergency contacts, update their neighborhood location.
* **FR-5 Session Management:** The system shall maintain active user sessions to prevent repeated authentication during normal usage.

***

### 3.2 Emergency Alert Module
**Description:** The Emergency Alert Module enables users to send instant SOS alerts to nearby community members and emergency responders.

**Functional Requirements:**
* **FR-6 SOS Panic Button:** The system shall provide a prominent SOS panic button on the application home screen. Pressing the button shall initiate an emergency alert process.
* **FR-7 Emergency Category Selection:** After triggering the SOS button, the system shall prompt the user to select the emergency type from the following categories: Theft / Robbery, Medical Emergency, Fire, Violence, Other.
* **FR-8 Alert Confirmation:** Before broadcasting the alert, the system shall request confirmation from the user to prevent accidental alerts.
* **FR-9 Alert Creation:** Upon confirmation, the system shall create a new emergency alert record in the Supabase database. The alert record shall include User ID, Emergency type, GPS coordinates, Timestamp, Alert status.
* **FR-10 Emergency Status Tracking:** The system shall track the status of each emergency alert. Alert states shall include ACTIVE, RESPONDED, RESOLVED.
* **FR-11 Alert Termination:** The user who triggered the alert shall be able to end the emergency alert manually once the situation is resolved.

***

### 3.3 Geo-Location Module
**Description:** This module handles location tracking and geographic filtering of alerts.

**Functional Requirements:**
* **FR-12 GPS Location Retrieval:** The system shall retrieve the user's current GPS coordinates using the mobile device's location services.
* **FR-13 Geo-Fence Filtering:** The system shall identify nearby users within a configurable alert radius (default 500 meters). Only users within this geographic boundary shall receive the alert.
* **FR-14 Live Location Updates:** If the emergency remains active, the system shall update the user's location periodically to reflect movement.
* **FR-15 Incident Mapping:** The system shall display active incidents on an interactive map interface. Users shall be able to view Incident location, Distance from the incident, Type of emergency.

***

### 3.4 Notification and Communication Module
**Description:** This module ensures that emergency alerts reach nearby users and authorities through multiple communication channels.

**Functional Requirements:**
* **FR-16 Push Notifications:** The system shall send real-time push notifications to nearby users using Firebase Cloud Messaging.
* **FR-17 Emergency Alert Message:** The notification shall contain Emergency type, Distance from the user, Approximate location, Alert time.
* **FR-18 Intrusive Alert Mode:** Emergency notifications shall override silent mode and trigger vibration and audible alerts.
* **FR-19 SMS Backup Notification:** If internet connectivity is unavailable, the system shall send emergency notifications via SMS.
* **FR-20 Emergency Contact Notification:** When an alert is triggered, the system shall notify the victim's registered emergency contacts.

***

### 3.5 Responder Module
**Description:** This module enables nearby residents to respond to emergency alerts.

**Functional Requirements:**
* **FR-21 Alert Reception:** Nearby users shall receive emergency notifications when an alert occurs within their geo-fence radius.
* **FR-22 Response Confirmation:** Users shall be able to respond to an alert by selecting the option: "I am coming to assist."
* **FR-23 Navigation Assistance:** The system shall provide navigation directions to the victim's location via the integrated map interface.
* **FR-24 Victim Communication:** Responders shall be able to initiate a phone call to the victim directly from the application.

***

### 3.6 Police Interface Module
**Description:** This module enables police authorities to receive and monitor emergency alerts.

**Functional Requirements:**
* **FR-25 Police Alert Notification:** Police stations registered within the system shall receive alerts related to emergencies within their jurisdiction.
* **FR-26 Incident Monitoring Dashboard:** Police officers shall be able to view a dashboard showing Active alerts, Incident locations, Emergency types, Alert timestamps.
* **FR-27 Incident Status Updates:** Police officers shall be able to update incident statuses such as Officer dispatched, Officer arrived, Case resolved.

***

### 3.7 Admin Dashboard Module
**Description:** The administrative interface allows system administrators to monitor and manage the platform.

**Functional Requirements:**
* **FR-28 User Management:** Administrators shall be able to View registered users, Suspend suspicious accounts, Verify user identities.
* **FR-29 Incident Monitoring:** Administrators shall be able to view all emergency alerts generated within the system.
* **FR-30 System Configuration:** Administrators shall be able to configure Alert radius distance, Emergency categories, Notification settings.
* **FR-31 Analytics and Reporting:** The system shall generate reports on Total registered users, Total incidents reported, Average response time, Most common emergency types.

**Summary of Functional Requirements:**
| Module | Requirements |
|---|---|
| Authentication | FR-1 – FR-5 |
| Emergency Alerts | FR-6 – FR-11 |
| Geo-Location | FR-12 – FR-15 |
| Notification System | FR-16 – FR-20 |
| Responder Module | FR-21 – FR-24 |
| Police Interface | FR-25 – FR-27 |
| Admin Dashboard | FR-28 – FR-31 |
| **Total Functional Requirements:** 31 |  |

***

# PART 3 — SYSTEM INTERFACES, NON-FUNCTIONAL REQUIREMENTS, DATA MODELS AND OTHER REQUIREMENTS

***

## 4. EXTERNAL INTERFACE REQUIREMENTS
External interfaces describe how the system interacts with users, hardware, software services, and communication protocols.

### 4.1 User Interface Requirements
The GuardianNode mobile application must provide a simple, accessible, and responsive interface suitable for users in high-stress situations.

**4.1.1 Mobile Application Interface**
The mobile interface shall include the following screens:

1. **Welcome / Onboarding Screen**
   * **Purpose:** Introduce users to the system.
   * **Features:** App introduction, Permission requests, Login or registration options.
   * **Permissions required:** GPS location, Notifications, Phone calls.

2. **User Authentication Screen**
   * **Components:** Phone number input, OTP verification input, Register / Login buttons.
   * **The interface must:** Provide clear instructions, Validate phone numbers before submission.

3. **Home Dashboard**
   * **The main screen must display:** Large SOS Panic Button, Current location indicator, Quick menu options.
   * **Example layout:**
      ```text
      GuardianNode

      📍 Mile 4 Nkwen

              🔴 SOS
         Hold 3 seconds to alert

      Nearby Incidents
      Safety Tips
      Community Map
      ```

4. **Emergency Category Selection Screen**
   * After pressing SOS, users must select an emergency category: Theft / Robbery, Medical Emergency, Fire, Violence, Other.
   * Each option should use icons and color coding for quick recognition.

5. **Emergency Response Screen**
   * Once an alert is triggered, the user should see: Alert status, Number of responders, Live map showing responders approaching.

6. **Community Map Screen**
   * **Displays:** User location, Active emergency incidents, Nearby community responders. Uses Google Maps integration.

7. **Responder Interface**
   * **Responders should see:** Alert notification, Emergency details, Navigation button, "I am coming" button.

8. **Profile Management Screen**
   * **Users can manage:** Profile information, Emergency contacts, Notification preferences.

***

### 4.2 Hardware Interface Requirements
The system interacts with mobile hardware components.
* **GPS Sensor:** Used to retrieve Latitude, Longitude, Movement tracking.
* **Mobile Network Adapter:** Required for Internet connectivity, SMS communication.
* **Notification Hardware:** Used to deliver vibration alerts, sound alerts, notification popups.

***

### 4.3 Software Interface Requirements
GuardianNode integrates with several external software services.

**4.3.1 Supabase Backend**
GuardianNode uses Supabase. Supabase provides PostgreSQL database, User authentication, Realtime database updates, API endpoints.
* **Responsibilities:** Store user data, Store incident alerts, Manage authentication, Enable real-time updates.

**4.3.2 Push Notification Service**
The system uses Firebase Cloud Messaging.
* **Used for:** emergency notifications, alert broadcasts, responder updates.

**4.3.3 SMS Gateway**
SMS fallback may use Twilio, Africa's Talking, Local telecom API.
* **Purpose:** Ensure alerts reach users even when internet connectivity fails.

**4.3.4 Mapping Services**
The system uses Google Maps Platform.
* **Functions include:** location display, navigation assistance, incident mapping.

***

### 4.4 Communication Interfaces
The system uses internet communication protocols.
* **Protocols used:** HTTPS (API communication), WebSockets / Realtime subscriptions (Supabase), REST API.
* **Communication flow:**
  ```text
  Mobile App -> HTTPS API -> Supabase Backend -> Notification Services
  ```

***

## 5. NON-FUNCTIONAL REQUIREMENTS
Non-functional requirements define system quality attributes.

### 5.1 Performance Requirements
* **Alert Delivery Time:** Emergency notifications must be delivered within 3 seconds after alert creation.
* **Location Detection Time:** GPS location retrieval should occur within 5 seconds after request.
* **System Response Time:** The mobile application should respond to user actions within 1–2 seconds.
* **Concurrent Users:** The system should support at least 5,000 simultaneous users across Cameroon.

### 5.2 Reliability Requirements
* **Reliability targets:** 99% system uptime, Automatic retry for failed notifications, SMS fallback in low connectivity areas.

### 5.3 Availability Requirements
* **Operational:** 24 hours a day, 7 days a week. Downtime must be limited to maintenance periods.

### 5.4 Security Requirements
* **Data Encryption:** All data transmitted between mobile app and server must use HTTPS encryption.
* **Authentication Security:** User authentication must use OTP verification, Secure token sessions.
* **Location Privacy:** User location must only be shared during active emergencies, with nearby users.
* **Data Access Control:** Role-based access must be implemented for users, police, administrators.

### 5.5 Usability Requirements
The application must be easy to use for individuals with limited technical knowledge.
* **Design principles:** simple navigation, minimal steps for emergency alerts, large touch buttons, clear icons.

### 5.6 Maintainability Requirements
The system must support future maintenance and upgrades.
* **Implementation practices:** modular architecture, documented APIs, version control.

### 5.7 Scalability Requirements
The system should be scalable to support continued growth across Cameroon and, in future, neighboring regions.
* Supabase infrastructure allows scaling through managed database clusters, cloud storage, distributed API endpoints.

***

## 6. DATA REQUIREMENTS (SUPABASE DATABASE MODEL)
The system database will be implemented using PostgreSQL within Supabase.

### 6.1 Users Table
`users` (id, name, phone_number, quarter, latitude, longitude, created_at)
* **Purpose:** Store registered user information.

### 6.2 Emergency Contacts Table
`emergency_contacts` (id, user_id, name, phone_number, relationship)
* **Purpose:** Store trusted contacts for each user.

### 6.3 Alerts Table
`alerts` (id, user_id, emergency_type, latitude, longitude, status, created_at)
* **Status values:** ACTIVE, RESPONDED, RESOLVED.

### 6.4 Responses Table
`responses` (id, alert_id, responder_id, response_status, created_at)
* **Purpose:** Track responders assisting victims.

### 6.5 Incident Logs Table
`incident_logs` (id, alert_id, action, timestamp)
* **Purpose:** Store system activity history.

***

## 7. SYSTEM MODELS

### 7.1 System Architecture Model
System architecture follows a client-server model.
```text
Flutter Mobile App -> API Layer -> Supabase Backend -> PostgreSQL Database
(External Services: Firebase + SMS connected to Backend)
```

### 7.2 Emergency Alert Process Model
Emergency flow:
1. User presses SOS
2. Location detected
3. Alert stored in database
4. Nearby users identified
5. Push notifications sent
6. Responders notified

***

## 8. FUTURE SYSTEM ENHANCEMENTS
Future improvements may include:
* **IoT Emergency Buttons:** Hardware panic buttons placed in homes using devices like ESP32 emergency node devices.
* **AI Crime Prediction:** Machine learning models analyzing incident patterns to predict high-risk areas.
* **Smart City Integration:** Integration with CCTV networks, smart street lights, public safety infrastructure.
* **Offline Mesh Network:** Allow devices to communicate using Bluetooth mesh networks when internet is unavailable.

***

# FINAL SRS SUMMARY
The GuardianNode system provides a community-driven emergency alert platform designed to improve safety across Cameroon.
Key capabilities include:
* Instant SOS alerting
* Geo-fenced emergency broadcasting
* Real-time location tracking
* Dual communication channels (Push + SMS)
* Police and administrative monitoring

The system architecture uses:
* Flutter mobile application
* Supabase backend
* PostgreSQL database
* Firebase push notifications
* Google Maps integration
