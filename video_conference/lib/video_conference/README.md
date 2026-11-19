TODO
draft:
Add an User portal. It is used when application is rented/shared with another external application.
Every user should have a portal where they can manage their applications.
  - add public key for stream servers
  - add api key to access application (to get list of urls to connect to stream servers)
Admin (admin portal) creates invitation link for a user to join the application.
Admin (admin portal) cannot create an invitation link for a user if other user already joined the application.
Admin (admin portal) cannot manage api keys of an application where user is assigned.

naming: rented application, shared application ... ()

refactor: Incapsulate list/edit in separate components