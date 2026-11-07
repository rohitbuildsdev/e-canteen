\# E-Canteen 🍽️



> A digital pre-ordering system designed to reduce waiting times and streamline order management in college canteens.



E-Canteen consists of \*\*two Flutter applications\*\* working together: a \*\*Student App\*\* for placing and tracking orders, and a \*\*Canteen App\*\* for managing orders and food availability.



\---



\## 📌 The Problem



College canteens often face long queues and inefficient order management, especially during breaks. Students spend valuable time waiting to place orders, while canteen staff have to manage multiple orders manually.



E-Canteen aims to make this process simpler by allowing students to \*\*place orders digitally\*\* and enabling canteen staff to \*\*manage orders through a dedicated application\*\*.



\---



\## 💡 The Solution



The system provides a complete digital order workflow:



\*\*Student places an order → Canteen accepts it → Food is prepared → Student is notified when it is ready for pickup.\*\*



\### Order Status Flow



```text

Placed → Accepted → Preparing → Ready for Pickup → Completed

```



\---



\## ✨ Features



\### 👨‍🎓 Student App



\- Browse the available canteen menu

\- View food items and prices

\- Add items to an order

\- Place orders digitally

\- Track order status in real time

\- View previous orders

\- Anonymous authentication using Firebase



\### 👨‍🍳 Canteen App



\- View incoming student orders

\- Accept and manage orders

\- Update order preparation status

\- Mark orders as ready for pickup

\- Manage food item availability

\- Dedicated interface for canteen-side operations



\---



\## 🛠️ Tech Stack



| Technology | Purpose |

|---|---|

| Flutter | Cross-platform application development |

| Dart | Application programming language |

| Firebase Authentication | User authentication |

| Cloud Firestore | Real-time database and order storage |

| Git \& GitHub | Version control and project hosting |



\---



\## 📂 Project Structure



```text

e-canteen/

├── e\_canteen\_student/       # Student-facing Flutter application

├── e\_canteen\_canteen/       # Canteen management Flutter application

├── docs/

│   └── screenshots/         # Application screenshots

├── .gitignore

└── README.md

```



\---



\## 📸 Screenshots



\### Student App



| Home | Menu |

|---|---|

| !\[Student Home](docs/screenshots/student\_home.png) | !\[Student Menu](docs/screenshots/student\_menu.png) |



| Cart / Order | Order Tracking |

|---|---|

| !\[Student Cart](docs/screenshots/student\_cart.png) | !\[Order Tracking](docs/screenshots/student\_order\_tracking.png) |



\### Canteen App



| Dashboard | Orders |

|---|---|

| !\[Canteen Dashboard](docs/screenshots/canteen\_dashboard.png) | !\[Canteen Orders](docs/screenshots/canteen\_orders.png) |



| Menu Management | Order Status |

|---|---|

| !\[Menu Management](docs/screenshots/canteen\_menu\_management.png) | !\[Order Status](docs/screenshots/canteen\_order\_status.png) |



> \*\*Note:\*\* Update the image filenames above to match your actual screenshot filenames.



\---



\## 🚀 Getting Started



\### Prerequisites



Make sure you have the following installed:



\- Flutter SDK

\- Dart SDK

\- Android Studio or another supported Flutter development environment

\- A Firebase project



\### Clone the Repository



```bash

git clone https://github.com/rohitbuildsdev/e-canteen.git

cd e-canteen

```



\### Run the Student App



```bash

cd e\_canteen\_student

flutter pub get

flutter run

```



\### Run the Canteen App



Open a separate terminal:



```bash

cd e\_canteen\_canteen

flutter pub get

flutter run

```



\---



\## 🔥 Firebase Setup



This project uses Firebase for authentication and data storage.



To run the project with your own Firebase configuration:



1\. Create a Firebase project.

2\. Enable \*\*Firebase Authentication\*\*.

3\. Create a \*\*Cloud Firestore\*\* database.

4\. Configure Firebase separately for both Flutter applications.

5\. Add your Firebase configuration files before running the applications.



Firebase configuration files are not included in this repository for security and project portability.



\---



\## 🚧 Current Status



The core ordering and order-management system is implemented.



\*\*Currently in development:\*\*



\- Payment functionality

\- Further improvements to the user experience



\---



\## 🔮 Future Improvements



\- Online payment integration

\- Push notifications for order updates

\- Analytics for canteen operations

\- Improved order management tools

\- AI-powered demand prediction and food recommendations



\---



\## 👨‍💻 Developer



\*\*Rohit Pappu\*\*



\- GitHub: \[rohitbuildsdev](https://github.com/rohitbuildsdev)

\- LinkedIn: \[rohitbuildsdev](https://www.linkedin.com/in/rohitbuildsdev)



\---



\### ⭐ Why this project matters



E-Canteen was built around a simple goal: \*\*identify a real problem faced by students and create a practical software solution for it.\*\*



The project demonstrates end-to-end thinking—from understanding the problem and designing the user flow to building separate applications for students and canteen operations.



