public with sharing class LeaveRequestController{

    @AuraEnabled
    public static Leave_Request__c createLeaveRequest(
    Leave_Request__c leaveRequest
){
    try{

         if (!FeatureManagement.checkPermission(
        'ELT_Create_Leave_Request'
    )) {
        throw new LeaveTrackerException(
            'You are not authorized to create leave requests.'
        );
    }
    if (leaveRequest == null) {
    throw new LeaveTrackerException(
        'Leave request information is required.'
    );
}
if (leaveRequest.Employee__c == null) {
    throw new LeaveTrackerException(
        'Employee is required.'
    );
}
if (leaveRequest.Manager__c == null) {
    throw new LeaveTrackerException(
        'Manager is required.'
    );
}

Employee__c employee = [
    SELECT Id, Manager__c
    FROM Employee__c
    WHERE Id = :leaveRequest.Employee__c
    WITH USER_MODE
    LIMIT 1
];

if (employee.Manager__c == null) {
    throw new LeaveTrackerException(
        'The employee does not have an assigned manager.'
    );
}

if (employee.Manager__c != leaveRequest.Manager__c) {
    throw new LeaveTrackerException(
        'Selected manager must match the employee assigned manager.'
    );
}

if (leaveRequest.From_Date__c == null) {
    throw new LeaveTrackerException(
        'From date is required.'
    );
}

if (leaveRequest.To_Date__c == null) {
    throw new LeaveTrackerException(
        'To date is required.'
    );
}
if (String.isBlank(leaveRequest.Leave_Type__c)) {
    throw new LeaveTrackerException(
        'Leave type is required.'
    );
}
if (String.isBlank(leaveRequest.Reason__c)) {
    throw new LeaveTrackerException(
        'Leave reason is required.'
    );
}
if (
    leaveRequest.From_Date__c != null &&
    leaveRequest.To_Date__c != null &&
    leaveRequest.To_Date__c < leaveRequest.From_Date__c
) {
    throw new LeaveTrackerException(
        'To date cannot be earlier than from date.'
    );
}
 leaveRequest.Status__c =
        'Pending Manager Approval';

    leaveRequest.Submitted_By__c =
        UserInfo.getUserId();

    insert as user leaveRequest;

    // Grant the assigned manager Edit access.
        LeaveTrackerSharingService.shareLeaveRequestWithManager(
            leaveRequest.Id,
            leaveRequest.Manager__c
        );

    return leaveRequest;

    } catch (LeaveTrackerException e) {

        AuraHandledException ex =
            new AuraHandledException(e.getMessage());

        ex.setMessage(e.getMessage());

        throw ex;

    } catch (Exception e) {

        AuraHandledException ex =
            new AuraHandledException(
                'Unable to create leave request.'
            );

        ex.setMessage(
            'Unable to create leave request.'
        );

        throw ex;
    }
 
}

@AuraEnabled(cacheable=true)
public static List<Leave_Request__c> getLeaveRequests(String status) {
    try {

        if (String.isBlank(status)) {

            return [
                SELECT
                    Id,
                    Name,
                    Employee__c,
                    Employee__r.Name,
                    Manager__c,
                    Manager__r.Name,
                    From_Date__c,
                    To_Date__c,
                    Leave_Type__c,
                    Reason__c,
                    Status__c,
                    Manager_Comment__c,
                    Submitted_By__c,
                    Submitted_By__r.Name,
                    Decision_Date__c,
                    Total_Days__c,
                    Is_Pending__c
                FROM Leave_Request__c
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];

        } else {

            return [
                SELECT
                    Id,
                    Name,
                    Employee__c,
                    Employee__r.Name,
                    Manager__c,
                    Manager__r.Name,
                    From_Date__c,
                    To_Date__c,
                    Leave_Type__c,
                    Reason__c,
                    Status__c,
                    Manager_Comment__c,
                    Submitted_By__c,
                    Submitted_By__r.Name,
                    Decision_Date__c,
                    Total_Days__c,
                    Is_Pending__c
                FROM Leave_Request__c
                WHERE Status__c = :status
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];
        }

    } catch (Exception e) {

        AuraHandledException ex =
            new AuraHandledException(
                'Unable to load leave requests.'
            );

        ex.setMessage(
            'Unable to load leave requests.'
        );

        throw ex;
    }
}
}