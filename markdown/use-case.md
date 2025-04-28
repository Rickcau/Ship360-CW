# Shipping Agent / CoPilot
Shipping Agent/Copilot assists users in retrieving shipping rates, tracking shipments, and Generate Shipping Label by integrating with various carrier APIs.
 
- Simplify shipping workflow – Conversational Shipping, Natural Language-Driven Shipping Workflow – No complex forms or UI/UX; Agentic AI understands intent and executes shipping operations.
- Addressing & Rating – Smart address validation and cost-optimized carrier rate selection.
- Label Printing & Tracking – Intelligent label generation and real-time tracking insights.
- Post-Purchase Experience – Predictive ETA updates and delivery notifications.
- Carrier Selection – Agent predicts the most cost-effective and fastest carrier.
 
**Business Impact**
-	Eliminates manual shipping complexity – just ask Agent AI!
-	Reduces mis deliveries, lowers costs, and enhances shipping efficiency.
-	Supports multi-channel integration (voice assistants, chatbots, enterprise apps).
 
## Actors: 
- End User (Customer, Business Owner, Logistics Manager)
 
## Preconditions
- User must be authenticated or provide sufficient details for request processing.
- System should have access to Shipping 360 API endpoints.
 
## Flow of Events
1. Intent Detection: The system identifies user intent (e.g., "Get me the cheapest shipping option").
2. Entity Extraction: The agent extracts details like package dimensions, weight, origin, destination, and carrier preferences.
3. Parameter Validation: The system checks for missing parameters and prompts the user accordingly.
4. API Call & Data Retrieval: The system queries carrier APIs for rates, estimated delivery times, and available services.
5. Response Generation: The AI presents the best shipping options with cost, speed, and reliability factors.
6. Print & Confirmation: If the user proceeds, the system print the shipment and provides a tracking number.

