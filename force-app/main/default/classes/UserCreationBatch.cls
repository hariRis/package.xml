/*****************************************************************************************************
 Apex Class   : UserCreation_Batch
 Description  : Create users with basic role and profile for the contacts created.
 Type         : Batch
 Version      : 1
 Developer    : Har
 Date         : 08/08/2023
 TestClass    : UserCreation_Batch_Test
 Code Coverage: 92%
 *****************************************************************************************************/

global class UserCreationBatch implements Database.Batchable<sObject>,Database.Stateful {
   // List<Exception_Log__c> userLog = new List<Exception_Log__c>(); //holds the success and failure  log records
    global Integer usersCreated = 0; //holds the count of newly created users.
    global Integer usersUpdated = 0; //holds the count of updated users.
    global Id exceptionRecordTypeId; //holds the exception record type Id.
    List<Contact> updatedContacts = new List<Contact>(); //Holds all the updated contact records.
    global final String query; //holds the query sent by the scheduler.
    /*Constructor*/
    global UserCreationBatch(String q){
        query =q; 

    }
    
    /*Start Method*/
    global  Database.QueryLocator start(Database.BatchableContext bc){
        //Schema.DescribeSObjectResult desExceptionLog = Exception_Log__c.SObjectType.getDescribe();// getting Sobject Type.
       // Map<String,Schema.RecordTypeInfo> exceptionRecordTypes = desExceptionLog.getRecordTypeInfosByName();// getting the record Type Info.
       // exceptionRecordTypeId =exceptionRecordTypes.get('Exception').getRecordTypeId();//Stores exception recordType Id.
       // return Database.getQueryLocator(query);
        return null;
    }
    global void execute(Database.BatchableContext bc, List<Contact> contacts){
        List<String> allContactEmails = new List<String>(); //Holds email of all the contacts.
        List<String> userIdInContact = new List<String>(); // Holds user Id of contact records.
        List<User> existingUsers = new List<User>(); //Holds the existing user records.
        Map<Id, User> activeUsersMap = new Map<Id, User>(); //Holds the existing active users.
        Map<String, User> inActiveUsersMap = new Map<String, User>(); //Holds the existing inActive users.
        List<User> allUsers = new List<User>(); //Holds all the users based on email.
        Map<String, User> allUsersMap = new Map<String,User>(); // Holds all the users in map.
        Map<String, User> activeUsersWithEmailMap = new Map<String,User>(); //Holds all the active users.
        Map<String, User> inActiveUsersWithEmailMap = new Map<String,User>(); //Holds all the inactive users.
        //List<Deloitte_Domains__c> domainList = Deloitte_Domains__c.getAll().values(); // Holds all the domain names from deloitte domain custom settings.
        Set<String> domainSet = new Set<String>(); //Holds the unique domain names.
        List<User> updateUsers = new List<User>(); //Holds all the existing user records to be updated.
        Set<Id> profileIds = new Set<Id>(); //Holds the profile Ids.
        List<User> newUserList = new List<User>(); //Holds all the newly created user records.
        CaseAndContact_Values__c CusSettings;//Holds the custom setting Values
        CusSettings=CaseAndContact_Values__c.getOrgDefaults();//Holds the values of custom setting fields
        String profileName = CusSettings.Default_Profile_For_Employees__c;//Reading profile name from customsetting.
        List<Profile> employeeProfile = [Select Id, Name from Profile Where Name =: profileName];//querying the profile based on the profile name.
        String roleName = CusSettings.Default_Role_For_Employees__c;//Reading role name from customsetting.
        List<PermissionSetLicenseAssign> PSL=new list<PermissionSetLicenseAssign>();//permission set license assignment to access  CaseObject 
        string PSLc =CusSettings.Permission_set_license_Id__c;//holds the permission set license Id
        List<UserRole> employeeRole = [Select Id, Name from UserRole Where Name=: roleName]; //querying the role based on the role id.
      
                
        try{
            //Initialzing map to store the users time zone
            Map<String,String> timeZoneForUser=new Map<String,String>(); // Region , TimeZonSidCode
            timeZoneForUser.put('EAST','America/New_York');
            timeZoneForUser.put('CENTRAL','America/Chicago');
            timeZoneForUser.put('WEST','America/Los_Angeles');
            timeZoneForUser.put('USI','Asia/Kolkata');
            //Iterate through all contacts
            for(Contact it : contacts){
                allContactEmails.add(it.Email); //adding the emails to list.
                if(it.Email != null && it.User__c!= null){
                    userIdInContact.add(it.User__c); //adding the user id if contact record as user record associated with it.
                }
            } 
           System.debug('userIdInContact:'+userIdInContact);
            //Querying the users present on contact records.
            if(userIdInContact.size()>0){
                existingUsers = [select id,Email,UserName,isActive,profileId,FederationIdentifier,CommunityNickName from User where id IN :userIdInContact  Order by createddate ASC]; //Need to change
            }
            System.debug('existingUsers:'+existingUsers);
           //Iterate through existing users
            for(User it : existingUsers){
                if(it.IsActive == true){
                    activeUsersMap.put(it.Id, it); //if its active user, add it to activeUserMap. 
                }
                else{
                    inActiveUsersMap.put(it.Email, it); //if its inactive user, add it to inactiveUserMap.
                }
            }
           System.debug('activeUsersMap:'+activeUsersMap);
            //Querying the user records based on contact email.
            allUsers=[select id,Email,UserName,isActive,profileId,FederationIdentifier,CommunityNickName from User where email IN :allContactEmails Order by createddate ASC];
            //Iterate through all users
            for(User it : allUsers){
                allUsersMap.put(it.email, it);
            }
           //Iterate through contacts
            for(Contact it : contacts){
                if(allUsersMap.containsKey(it.Email)){
                    User u = allUsersMap.get(it.email);
                    if(u!=null){
                        if(u.IsActive==true){
                            activeUsersWithEmailMap.put(u.Email, u); //if its active user, add it to activeUsersWithEmailMap.
                        }
                        else{
                            inActiveUsersWithEmailMap.put(u.Email, u); //if its inactive user, add it to inActiveUsersWithEmailMap.
                        }
                    }
                }
            }
           /*Iterate through domain names from custom settings.
            for(Deloitte_Domains__c it : domainList){
                if(it.Domain_Name__c != null){
                    domainSet.add(it.Domain_Name__c);
                }
            }*/
           
            //Looping all the contacts
            for(Contact it : contacts){
                //If contact has user
                if(it.User__c!=null){
                    if(activeUsersMap.containsKey(it.User__c)){
                        User u = activeUsersMap.get(it.User__c);
                        //Checking for change in email, if true inactivate the existing user record and create new user record. 
                        if(u.Email != null && u.Email != it.Email){
                            System.debug('Making user record inactive');
                            u.IsActive = false;
                            updateUsers.add(u);
                            //check for active user record with same email
                            User activeUser = activeUsersWithEmailMap.get(it.Email);//check for user record
                            if(activeUser != null){
                               //do nothing - This is handled in another batch class
                            }
                            else{
                                String domEmail = it.Email.substringAfter('@');
                                if(domainSet.contains(domEmail)){                                  
                                    //Create new user.
                                    User newOne = createNewUser(it,timeZoneForUser,employeeProfile[0].id,employeeRole[0].id);
                                    newUserList.add(newOne); //adding the new user to list
                                }
                            }  
                        }
                    }
                    else{
                            User activeUser = activeUsersWithEmailMap.get(it.Email);//check for user record
                            if(activeUser != null){
                                //do nothing - This is handled in another batch class
                            }
                            else{
                                User inactiveUser = new User();
                                inactiveUser.id = it.User__c; //inactive user with same email.
                                inactiveUser.IsActive = true;
                                //inactiveUser.Contact_ID__c=it.Id;
                                updateUsers.add(inactiveUser);
                            }       
                    }
                }
                //If contact don't have user
                else{
                    if(activeUsersWithEmailMap.get(it.Email)!=null){
                        User activeUserWithSameEmail = activeUsersWithEmailMap.get(it.Email);
                        if(activeUserWithSameEmail != null){
                            //do nothing - This is handled in another batch class
                        }     
                    }
                    else{
                        User inactiveUserRecord = inActiveUsersWithEmailMap.get(it.Email);
                        //Updating the existing inactive user record with .ex
                        if(inactiveUserRecord!=null){
                            String userName = inactiveUserRecord.Username;
                            if(!userName.contains('prd.ex')){
                                inactiveUserRecord.Username += '.ex';
                                inactiveUserRecord.FederationIdentifier += '.ex';
                                inactiveUserRecord.CommunityNickname += '.ex';
                                updateUsers.add(inactiveUserRecord);
                            }
                        }
                         
                        //Creating a new user
                        if(it.Email != null && (it.Email.containsIgnoreCase('@deloitte'))){                         
                            User newUser = createNewUser(it,timeZoneForUser,EmployeeProfile[0].id,employeeRole[0].id);                         
                            newUserList.add(newUser);
                           
                        }
                    }
                }
                //it.User_Management_Category__c=false;
                updatedContacts.add(it);
            }//End of for loop
           
            /* Updating the existing user records */
            if(updateUsers.size()>0){
                existingUserUpdate(updateUsers);
            }

            /* Inserting new user records */
            if(newUserList.size()>0){
                insertNewUsers(newUserList);
            }
          
    }
        Catch(Exception e){
            //userLog.add(New Exception_Log__c(className__c='User Creation',pageName__c='Try block failed',Exception_Date_and_Time__c=system.now(),Detailed_Exception__c=e.getMessage()+ e.getLineNumber(),RecordTypeId= exceptionRecordTypeId,Running_User__c = UserInfo.getUserId()) );
        }
    }
    
    global void finish(Database.BatchableContext bc){
    }
    
    //This method will create new users.
    private User createNewUser(Contact it, Map<String,String> timeZoneForUser, Id profileId, Id roleId){
        if(it!=null){
            String userEmail = it.Email;
           // String userTitle = it.WCT_Office_City_Personnel_Subarea__c;
            //userTitle = userTitle + ',' + userEmail;
            User newUserRec = new User();
            newUserRec.FirstName = it.FirstName;
            newUserRec.LastName = it.LastName;
            newUserRec.Username = it.Email + '.ar.prd';
            newUserRec.ProfileId = profileId;
            newUserRec.UserRoleId = roleId;
            newUserRec.Email = it.Email;
            newUserRec.FederationIdentifier = (it.Email).split('@')[0];
            /*Alias Calculation:
            1. Firt Character of First Name. 
            2. Three Characters of Last Name, if atleast 3 characters Or 2 or 1 
            */
            newUserRec.Alias='';
            if(it.FirstName != null && it.FirstName != ''){
                newUserRec.Alias = (it.FirstName).substring(0,1);
            }
            if(it.LastName.length()>=3){
                newUserRec.Alias = newUserRec.Alias + it.LastName.substring(0, 3);
            }
            if(it.LastName.length()==2){
                newUserRec.Alias = newUserRec.Alias + it.LastName.substring(0, 2);
            }
            if(it.LastName.length()==1){
                newUserRec.Alias = newUserRec.Alias + it.LastName.substring(0, 1);
            }
            newUserRec.CommunityNickname = (it.Email).split('@')[0];
            newUserRec.IsActive = true;
            if(it.WCT_Region__c == null || it.WCT_Region__c == ''){
                newUserRec.TimeZoneSidKey = 'America/El_Salvador';
            }
            else{
                string region = it.WCT_Region__c;
                if(region.containsIgnoreCase('USI')){
                    newUserRec.TimeZoneSidKey=timeZoneForUser.get('USI');
                }else  if(region.containsIgnoreCase('WEST')){
                    newUserRec.TimeZoneSidKey=timeZoneForUser.get('WEST');
                }else  if(region.containsIgnoreCase('EAST')){
                    newUserRec.TimeZoneSidKey=timeZoneForUser.get('EAST');
                }else  if(region.containsIgnoreCase('CENTRAL')){
                    newUserRec.TimeZoneSidKey=timeZoneForUser.get('CENTRAL');
                }else{
                    newUserRec.TimeZoneSidKey='America/El_Salvador';     
                }
            }
            newUserRec.LanguageLocaleKey='en_US';
            newUserRec.LocaleSidKey='en_US';
           // newUserRec.Contact_ID__c=it.Id;
            newUserRec.EmailEncodingKey ='ISO-8859-1';
            newUserRec.EmailPreferencesAutoBcc=false;
            newUserRec.EmailPreferencesAutoBccStayInTouch=false;
            newUserRec.EmailPreferencesStayInTouchReminder=true;
            newUserRec.UserPreferencesTaskRemindersCheckboxDefault=true;
            newUserRec.ReceivesAdminInfoEmails=false;
            newUserRec.ReceivesInfoEmails=false;
            //newUserRec.UserPreferencesEventRemindersCheckboxDefault=true;
            //newUserRec.Title = userTitle;
            return newUserRec;
        }
        return null;
    }
        //This method will update the existing user records.
    private void existingUserUpdate(List<User> updateUsers){
        List<Id> updatedUserIds = new List<Id>(); //Holds the successfully updated user record Id's. 
        Database.DMLOptions dlo = new Database.DMLOptions();
        dlo.EmailHeader.triggerUserEmail = false;
        Database.SaveResult[] existingUsersSaveList = Database.update(updateUsers, dlo);
        for(Integer i=0;i<existingUsersSaveList.size();i++){
            if(existingUsersSaveList.get(i).isSuccess()){
                updatedUserIds.add(existingUsersSaveList.get(i).getId());
            }
            else{
                for(Database.Error err:existingUsersSaveList.get(i).getErrors()){
                    string msg='Error while updating the already existing user : '+updateUsers.get(i)+':'+ err.getStatusCode() + ' :' + err.getMessage();
                    //userLog.add(New Exception_Log__c(className__c='UserCreation_Batch',pageName__c='Batch Class',Exception_Date_and_Time__c=system.now(),Detailed_Exception__c=msg,RecordTypeId= exceptionRecordTypeId,Running_User__c = UserInfo.getUserId()) );
                }
            }
        }
        usersUpdated += updatedUserIds.size(); //Stores the no of user records updated.     
    }

    //This method will insert new user records.
    private void insertNewUsers(List<User> newUserList){
        CaseAndContact_Values__c CusSettings;//Holds the custom setting Values
        CusSettings=CaseAndContact_Values__c.getOrgDefaults();//Holds the values of custom setting field
        List<PermissionSetLicenseAssign> PSL=new list<PermissionSetLicenseAssign>();//permission set license assignment to access  CaseObject 
        string PSLc =CusSettings.Permission_set_license_Id__c;//holds the permission set license Id
        system.debug('Permission_set_license_Id__c : '+PSLc);
        List<Id> newUserIds = new List<Id>(); //Holds the newly created user record Id's.
        Database.DMLOptions dlo = new Database.DMLOptions();
        dlo.EmailHeader.triggerUserEmail = false;
        Database.SaveResult[] newUsersSaveList = Database.insert(newUserList, dlo);
        System.debug('ListSize : '+newUsersSaveList.size());
         System.debug('ListSize : '+newUsersSaveList[0]);
        for(Integer i=0;i<newUsersSaveList.size();i++){
            if(newUsersSaveList.get(i).isSuccess()){
                newUserIds.add(newUsersSaveList.get(i).getId());
                system.debug('newUserId :'+newUserIds);
            }
            else{
                for(Database.Error err:newUsersSaveList.get(i).getErrors()){
                    string msg='Error while updating the already existing user : '+newUserList.get(i)+':'+ err.getStatusCode() + ' :' + err.getMessage();
                    //userLog.add(New Exception_Log__c(className__c='UserCreation_Batch',pageName__c='Batch Class',Exception_Date_and_Time__c=system.now(),Detailed_Exception__c=msg,RecordTypeId= exceptionRecordTypeId,Running_User__c = UserInfo.getUserId()) );
                }
            }
        }
        usersCreated = usersCreated + newUserIds.size(); //holds the count of newly created users
        // Assign Permission Sets to Users based on their License
    List<PermissionSetAssignment> permissionSetAssignmentsToInsert = new List<PermissionSetAssignment>();
    Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Admin Permissions' LIMIT 1].Id;//Holds the  permission set Id of Webforms
     
    for (User newUser : [SELECT Id, Profile.UserLicense.Name FROM User WHERE Id IN :newUserIds]) {
        String userLicenseName = newUser.Profile.UserLicense.Name;
        System.debug('userLicenseName :'+userLicenseName);
        // Check user's license and assign corresponding permission set
        if (userLicenseName == 'Salesforce') {
            // Assign PermissionSet1 Id to users with Salesforce license
            
        } else if (userLicenseName == 'Salesforce Platform') {
             PermissionSetLicenseAssign p = new PermissionSetLicenseAssign();
                        p.PermissionSetLicenseId=PSLc;
                        p.AssigneeId=newUser.id;
                        PSL.add(p);
         
            PermissionSetAssignment psa = new PermissionSetAssignment(
                PermissionSetId = permSetId,
                AssigneeId = newUser.Id
            );
            permissionSetAssignmentsToInsert.add(psa);
        }
    }
        
        // Insert the Permission Set LicenseAssign
    if (!PSL.isEmpty()) {
        Database.insert(PSL);
    }
    
    // Insert the Permission Set Assignments
    if (!permissionSetAssignmentsToInsert.isEmpty()) {
        Database.insert(permissionSetAssignmentsToInsert);
    }
}
    // Helper method to get Permission Set Id by its Name
private String getPermissionSetIdByName(String permissionSetName) {
    List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
    return (permissionSets.isEmpty()) ? null : permissionSets[0].Id;
}


    

}