---
type: ISO27001 Procedure
title: How To - Access Control and Role Based Access
description: |
  #### What you use this for
  Step-by-step for admins: grant, review, and revoke access using your role model.
  
  #### When it counts
  When onboarding tools or training new administrators.
  
  #### Connected artefacts
  - `is-02-access-control-policy`
  - `role-based-access-control`
  - `access-request-form`
  
  #### Review rhythm
  **Annual**; update when IdP or ticketing changes.
  
  #### First move
  Walk through a fictional new hire with your real tools.
---

# How to Manage Access Control

Access control to systems is managed technically within the systems that you deploy. The requirement is to record the level of access that people have and to audit and check that on a regular basis.

## Starter Leaver Mover

Access control needs to be changed when a user starts with the company, moves role within the company and then leaves the company.

You will need a starter, leaver, mover process that is outside the scope of this document and usually provided by the HR function. BUT you should include the process of managing system access within that. It is usual to list out the type of access required, get authorisation from a manager, and then allocate it to a ticket system or some way of evidencing that it was actioned.

## Recording Access Control

There are many ways to record the access that employees have to systems. The accompanying spreadsheet – Roles Based Access Control – is a convenient method in the absence of any other. The requirements on the recording are that it makes your life easier and speeds up the process of review and checking as well as evidencing to auditors and interested parties that you are on top of the process.

The spreadsheet provides for 2 options and 2 scenarios. Let us take each one in turn. Choose the method that is most appropriate to your situation and then remove the tabs for the one that you are not using. Note that in the spreadsheet there is guidance on what to do. This text should also be removed as it is there to help you with setup.

## Option 1- Simplistic Access List

The simple access control list can be used for small numbers of employees and less complex environments. Its limitations quickly become apparent as the size of employees or systems increases but is a great first step. In basic terms it just lists the employees, the system and sub system they use and the access they have. As this is a line per user, per system, per sub system you can see how this will quickly become a large list for reviewing.

## Option 2 – Role Based Access

On the face of it this looks more complex but on closer inspection its actual simplicity becomes apparent. For Role Based Access there are 2 tabs. First, we record the roles in the first tab. Then we record the employees and assign those roles in the second tab. There is a small effort to understand and define the roles. It is advised that the role names are standardised and kept to a minimum, even across the various systems. Terms such as Admin, Sys Admin, User, Developer, Tester are advised.

Understanding the type of access per environment can be recorded in any format and it is suggested the Read/ Write / Execute model is a good one. You are free to define your own.

## Exceptions

Exceptions are where employees have access that is not standard and does not adhere to standard defined roles. In these cases, first see if you can define a role for this type of access. If not, then on the employee assignment page just record the employee as an exception and notes to the notes field. This level of exceptional access as a rule requires Management Review Team meeting sign off and would be recorded in the minutes of the next available Management Review Team. Of course, you may have a different authorisation method and in this case record that in the notes but make sure that you have some evidence to show it was authorised – examples being an email chain, an internal ticket system. Exceptional access should never be granted without authorisation and an evidence trail of the authorisation.

## Reviewing Access Control

The level of access needs to be reviewed and audited on a periodic basis. The review should be completed by the system owner. Who ever does the review should maintain a log of the reviews so that they can evidence they took place. The best approach is to record in the minutes of operational meetings that the reviews are taking place. To aid the evidence gathering and to demonstrate to auditors that we are doing the review the accompanying document – Access Review Log – is a simple log of what type of review was performed, when and by whom. It includes a column for notes but also for any support / helpdesk / work tickets that may arise due to the review. An example would be where a review as conducted, and it was seen that leavers still had system access that was not removed as part of the leaver process – in this instance we may raise a ticket to have the access removed. This creates an auditable evidence chain that the process is working.
