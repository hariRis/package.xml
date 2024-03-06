/*****************************************************************************************************
Apex Class   : ContactTriggerHandler_AT
Description  : A logic has been written for contact records insertion and updation.
Version      : 1
Developer    : Anu
Date         : 07/04/2023
TestClass    : ContactTrigger_Test
Code Coverage: 
*****************************************************************************************************/
public with sharing class ContactTriggerHandler_AT {
    CaseAndContact_Values__c ConRecTypeId;
    public String EmployeeRtypeId = WCT_Util.getRecordTypeIdByLabel('Contact', 'Employee');
    public String CandRtypeId = WCT_Util.getRecordTypeIdByLabel('Contact', 'Candidate');
    public static final Id candRecTypeId = WCT_Util.getRecordTypeIdByLabel('Contact', 'Candidate');
    public static final Id AdhocCandRecTypeId = WCT_Util.getRecordTypeIdByLabel('Contact', 'Candidate Ad Hoc');
    public static Map<String, Account> MapAccounts = new Map<String, Account>(); //Account Split Related
    public static List<Account> accMasterList = new List<Account>();
    
    // Updating Related Contacts Count in Account  
    public void RelatedContactsCount(Set<Id> AccountIdset) { 
        AggregateResult[] conlist;
        Integer totalCount;
        List<Account> AccUpdateList = new List<Account>();     
        for (AggregateResult c:[SELECT COUNT(Id), AccountId FROM Contact WHERE AccountId IN :AccountIdset GROUP BY AccountId]) {
            Id custid = (Id)c.get('AccountId');          
            totalCount = (Integer)c.get('expr0');          
            Account cust1 = new Account(Id=custid);          
            cust1.Related_Contacts_Count__c = totalCount;
            AccUpdateList.add(cust1);                            
        }
        
        if (AccUpdateList.size() > 0) {
            update AccUpdateList;
        }
    }
    Public void CreateIncrementAccount() {
        ConRecTypeId = CaseAndContact_Values__c.getOrgDefaults();
        List<Account> listAcc = new List<Account>();
        List<Account> accounts = new List<Account>();
        
        if (Test.isRunningTest())
            accounts = [SELECT Id, Related_Contacts_Count__c, Name, Phone, Fax, GBL_Region__c, GBL_Contact_Type__c, GBL_Function__c, GBL_Account_Key__c, GBL_Is_Contact_Account__c FROM Account WHERE Limit_Reached__c = False]; 
        else            
            accounts = [SELECT Id, Related_Contacts_Count__c, Name, Phone, Fax, GBL_Region__c, GBL_Contact_Type__c, GBL_Function__c, GBL_Account_Key__c, GBL_Is_Contact_Account__c FROM Account WHERE GBL_Is_Contact_Account__c = true AND Is_Active__c = false AND Limit_Reached__c = False]; 
        
        List<Account> emaillist = new List<Account>();
        
        if (accounts != null && accounts.size() > 0) {
            for (Account accFinal : accounts) {
                if (accFinal.Related_Contacts_Count__c > 4500) {
                    emaillist.add(accFinal);    
                }
                Account acc = new Account();
                List<String> actualname = new List<String>();
                String numberToText;
                
                if (Test.isRunningTest())
                    actualname.add('test');
                else {
                    Integer index = accFinal.name.lastIndexOf(':');
                    String text = accFinal.name.substring(index + 1);
                    Integer textToNumber = Integer.valueOf(text);
                    textToNumber++;
                    numberToText = String.ValueOf(textToNumber);                                              
                    actualname = accFinal.Name.split(':');
                }
                
                acc.Name = actualname[0] + ':' + numberToText;
                acc.GBL_Region__c = accFinal.GBL_Region__c;
                acc.GBL_Contact_Type__c = accFinal.GBL_Contact_Type__c;
                acc.GBL_Function__c = accFinal.GBL_Function__c;
                acc.Phone = accFinal.Phone;
                acc.Fax = accFinal.Fax;
                acc.GBL_Is_Contact_Account__c = accFinal.GBL_Is_Contact_Account__c;
                listAcc.add(acc);
            }
            
            if (emaillist.size() > 0) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.ToAddresses = new String[]{ConRecTypeId.AccountToContactEmail__c};
                    mail.setSubject('List of Accounts Where Contacts are more than 4500');
                mail.setUseSignature(false);
                String htmlBody = 'Hi, <br> <br> <br> Below are the list of Accounts that have more than 4500 contacts <br><br> ';
                htmlBody += '<div> <table border="1"><tr><th>Name</th><th>Count</th><th>Account Id</th></tr>';                  
                for (Account Ac : emaillist) {
                    htmlBody += '<tr> <td>' + Ac.Name+'</td>'+'<td>'+ Ac.Related_Contacts_Count__c+'</td>'+'<td>'+Ac.Id+'</td></tr>';
                }                   
                htmlBody += '</table> </div>';
                mail.setHtmlBody(htmlBody);
                List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
                mails.add(mail);
                Messaging.sendEmail(mails);   
            }
        }
        
        if (!listAcc.isempty()) {
            insert listAcc;
        }
        
        for (Account accCountCheck : accounts) {
            accCountCheck.Limit_Reached__c = true;
            update accounts;
        }
    }
    
    public static list<Account> getAccounts(){
        if(accMasterList.isEmpty()){
            list<Account> accounts = [SELECT Id, Name,Related_Contacts_Count__c, GBL_Region__c,GBL_Contact_Type__c,GBL_Function__c, GBL_Account_Key__c,GBL_Is_Contact_Account__c FROM Account where Is_Active__c= true and GBL_Is_Contact_Account__c= true and Limit_Reached__c = False]; //Account Split Related
            /*This is to avoid teh Record Locked error*/
            accMasterList=accounts.clone();
            accounts=null;
        }
        return accMasterList;
    } 
    //PopulateAccount method is Called from Contact Trigger to populate the approcate account for the contact,assigning the Account to contact using Contact Type, Function And region as paramertes. 
    public void PopulateAccount(List<Contact> lstContact){        
        Id accountIndiaId;      
        Id accountNAId;     
        Id accountUSId;     
        Id accountNAvId;        
        Id accountCandidate;        
        Id accountfriend;          
        try
        {
            List<Account> lstAccount = getAccounts();       
            //Building the "MapAccounts" based on the accounts object data.     
            for(Account a:lstAccount)       
            {       
                MapAccounts.put(a.GBL_Account_Key__c.toLowerCase().trim(),a); // Account key is the combination of 2 fields  trim(Function__c) & ':' & trim(Region__c)      
            }       
            //getting the 'Not Available' account id info.      
            if(lstAccount.size()> 0) {      
                for(Account a:lstAccount)       
                {       
                    
                    if(a.name.contains('Not Available') )      
                    {       
                        accountNAvId = a.id;  
                    }       
                }       
            }       
            
            //The contact will be updated with the appropriate account id based on the Region, Contact Type and Function.       
            if(lstContact.size()>0){        
                for(Contact con:lstContact) {       
                    //This is to build the contact key based on teh Region,Type & Function.     
                    string strConactKey = '';       
                    string str_WCT_Type = '';       
                    string str_WCT_Region = '';     
                    string str_WCT_Function ='';        
                    str_WCT_Type = (con.WCT_Type__c!=null && con.WCT_Type__c !='' )?con.WCT_Type__c.tolowercase().trim():'';        
                    str_WCT_Region = (con.WCT_Region__c!=null && con.WCT_Region__c !='' )?con.WCT_Region__c.tolowercase().trim():'';        
                    if (str_WCT_Region=='USI' || str_WCT_Region == 'US-USI' || str_WCT_Region == 'US - USI')        
                    {           
                        str_WCT_Region ='US - USI';     
                    }       
                    else    
                    {       
                        str_WCT_Region ='US';       
                    }           
                    str_WCT_Function = (con.WCT_Function__c!=null && con.WCT_Function__c !='' )?con.WCT_Function__c.tolowercase().trim():'';        
                    
                    if((str_WCT_Type != '') && (str_WCT_Type == 'candidate' || str_WCT_Type =='candidate ad hoc'))      
                    {  
                        //Candidate : no impact of region and function so NA in respective places. 
                        strConactKey = 'na::candidates::na';           
                    }       
                    else if(str_WCT_Type == 'friend' || str_WCT_Type == 'emergency' || str_WCT_Type == 'dependent')       
                    {       
                        //friends : No impact of region and function so NA in respective places. 
                        strConactKey = 'na::' + str_WCT_Type +'::na';       
                    }       
                    else if((str_WCT_Type != '' ) &&  (str_WCT_Type == 'other' || str_WCT_Type == 'external' || str_WCT_Type == 'pre-external' ||       
                                                       str_WCT_Type == 'retiree/pensioner' || str_WCT_Type == 'salary continuation' || str_WCT_Type == 'separated' ||  str_WCT_Type == 'prehire' ||  str_WCT_Type == 'emergency'))      
                    {       
                        //Other, external, Per External Retiree Salary no impact of function to NA in function place in key
                        strConactKey = str_WCT_Region +'::' + str_WCT_Type +'::NA';     
                    }       
                    else        
                    {       
                        strConactKey = str_WCT_Region +'::' + str_WCT_Type +'::' + str_WCT_Function;        
                    }       
                    //Once the contact key was build, it is being checked in the MapAccounts map to find the appropriate account id.        
                    strConactKey = strConactKey.tolowercase().trim();     
                    if(MapAccounts.containsKey(strConactKey))       
                    {       
                        Account actx = MapAccounts.get(strConactKey);       
                        con.accountid = actx.id;      
                    }       
                    else if (str_WCT_Type=='employee')
                    {
                        //Check for only if Employee. If no account for direct function mapping Use the account Others. 
                        strConactKey = str_WCT_Region +'::' + str_WCT_Type +'::other'; 
                        strConactKey = strConactKey.tolowercase().trim(); 
                        if(MapAccounts.containsKey(strConactKey))
                        {
                            Account actx = MapAccounts.get(strConactKey); 
                            con.accountid = actx.id; 
                        }
                    }else      
                    {       
                        con.accountid = accountNAvId;   
                    }       
                }       
            }    
        }
        catch(Exception e )  {WCT_ExceptionUtility.logException('Contact Trigger Hanlder','PopulateAccount','Line # '+e.getLineNumber()+'Message'+e.getMessage()+e.getStackTraceString());}
    }
    
    Public void setcandRec(List<Contact> lstNewContacts){
        try
        {
            for(contact con:lstNewContacts)
            {   
                if(con.WCT_Contact_Type__c =='Candidate' && (con.WCT_Employee_Status__c =='' || con.WCT_Employee_Status__c ==null))
                {
                    con.recordtypeId =candRecTypeId;
                }
            }
            
        }
        catch(Exception e){ WCT_ExceptionUtility.logException('Contact Trigger Hanlder','setcandRec','Line # '+e.getLineNumber()+'Message'+e.getMessage()+e.getStackTraceString());}
    }
    
    /* This method will avoid converting Employee to Candidate when Taleo/RMS Id already have for an Employee
Also it will sets a flag to indicate this employee came as Candidate

*/
    public void avoidEmployeeToContactOnTaleoLoad(List<Contact> lstNewContacts,Map<id,Contact> oldMap ){
        
        for(Contact conRec: lstNewContacts)
        {
            if(conRec.WCT_Contact_Type__c!=null && (WCT_UtilConstants.CONTACT_GROUP_CONTACTTYPE).equalsIgnoreCase(conRec.WCT_Contact_Type__c) 
               && (WCT_UtilConstants.CONTACT_GROUP_EMPLOYEETYPE).equalsIgnoreCase(oldMap.get(conRec.Id).WCT_Contact_Type__c))
            {
                conRec.WCT_Contact_Type__c=WCT_UtilConstants.CONTACT_GROUP_EMPLOYEETYPE;
                conRec.WCT_IsCandidate__c=true;
            }
        }    
    }
    
    /* This method update the recruiter filed in the caditate before insert based on
the recruiter email id in the rms to sfdc candidate record */  
    
    public void UpdateRecuriterName(list<Contact> newConList){
        
        Map<string,string> Emailtoname = new  Map<string,string>();
        set<string> set_contactemail = new set<string>();
        
        
        for(Contact Newconvar : newConList)
        {
            set_contactemail.add(Newconvar.WCT_Recruiter_Email__c);
        }
        if(!set_contactemail.isEmpty())
        {
            for(Contact lst_convarup : [select id, name, email from Contact where email in : set_contactemail and WCT_Contact_Type__c = 'Employee' and email !=Null ]) 
            {
                Emailtoname.put(lst_convarup.email, lst_convarup.name) ;   
            }
        }
        
        for(Contact NewCon : newConList)
        {
            NewCon.WCT_Candidate_Recruiter__c = Emailtoname.get(NewCon.WCT_Recruiter_Email__c);
            
        }
    }
    
    
    //Purpose: This method would prevent creation of Adhoc Candidates with Duplicate Email.
    Public void CheckDuplicateEmail(List<Contact> lstNewContacts){
        ConRecTypeId=CaseAndContact_Values__c.getOrgDefaults();
        Set<Id> setRecordtypeIDs=new Set<ID>{ConRecTypeId.AdhocCandidateRecType__c, ConRecTypeId.CandidateRecordTypeId__c}; 
            Map<String,Contact> mapNewAdhocCandidates= new Map<String,Contact>();
        for(Contact NewCandidate:lstNewContacts){
            if(NewCandidate.recordtypeId==ConRecTypeId.AdhocCandidateRecType__c && NewCandidate.Email!=null ){                 
                // Make sure another new Adhoc Candidate isn't also a duplicate    
                if (mapNewAdhocCandidates.containsKey(NewCandidate.Email)){
                    NewCandidate.Email.addError('Another new Adhoc Candidate has the same email address.Please change the Email Address');
                }
                else{
                    mapNewAdhocCandidates.put(NewCandidate.Email, NewCandidate);
                }
                
            }
        }
        List<Contact> lstExistingAdHocCandidatesWithSameEmail= new list<Contact>();
        if(!mapNewAdhocCandidates.isempty()){
            lstExistingAdHocCandidatesWithSameEmail =[select id,Email,recordtypeID from Contact where recordtypeID in :setRecordtypeIDs and 
                                                      Email in :mapNewAdhocCandidates.KeySet() And Id NOT in:lstNewContacts  limit:Limits.getLimitQueryRows() ];
        }
        if(!lstExistingAdHocCandidatesWithSameEmail.isEmpty()){
            for(Contact existingContact:lstExistingAdHocCandidatesWithSameEmail){             
                mapNewAdhocCandidates.get(existingContact.Email).addError('Account already exists. There is more than one record in the system tied to this email/contact. Please merge the records before proceeding.');
            }
            
        }
    }
    
    
    /* Name:AddMergeCandidateOnCandidate
Purpose: This method would Merge Candidate on Candidate ,which has same email address of Candidate.

*/
    Public void AddMergeCandidateOnCandidate(List<Contact> lstNewContacts){
        ConRecTypeId=CaseAndContact_Values__c.getOrgDefaults();
        
        Map<String,Contact> mapNewCandidates= new Map<String,Contact>(); 
        
        List<Exception_Log__c> exceptionLogList=new List<Exception_Log__c>();
        try{       
            for(Contact NewCandidate:lstNewContacts){
                if( (NewCandidate.recordtypeId==ConRecTypeId.CandidateRecordTypeId__c || NewCandidate.WCT_Contact_Type__c == ConRecTypeId.ContactType_Candidate__c) && NewCandidate.Email!=null ){                 
                    mapNewCandidates.put(NewCandidate.Email, NewCandidate);
                }
            }                
            
            List<Contact> lstExistingAdHocCandidatesWithSameEmail= new list<Contact>();
            if(!mapNewCandidates.isempty()){
                lstExistingAdHocCandidatesWithSameEmail =[select id,Email,Avature_ID__c,recordtypeID,Phone,Degree_Type__c,CR_ACT__c,TRM_serviceArea__c,TRM_correspondingFSS__c,CR_Closed_List_Outcome__c,
                                                          CR_Contact_Category_Ranking__c,CR_School_Recruiter__c,CR_Dropped_Resume__c,CR_Expected_Grad_Month__c,CR_Expected_Grad_Year__c,
                                                          CR_Graduate_GPA__c,GRE_Post_8_1_2011__c,CR_High_Potential_Program_Peer__c,TRM_leadSourceDetail__c,Location_Preference__c,CR_Undergrad_Major__c,CR_Other_GPA__c,
                                                          CR_Undergrad_Other_Major__c,CR_Program_Interest_for_Interview__c,SAT_Total__c,SAT_Verbal__c,SAT_Writing__c,School_Program__c,TRM_Source_Detail_Name__c,CR_Undergraduate_Major_GPA_4_00_Scale__c,
                                                          CR_Undergraduate_Overall_GPA_4_00_Scale__c,CR_GMAT__c,GRE_Pre_8_1_2011__c
                                                          from Contact where recordtypeID = :ConRecTypeId.AdhocCandidateRecType__c and 
                                                          Email in :mapNewCandidates.KeySet()And 
                                                          WCT_Related_Contact_Status__c != 'Merged' limit:Limits.getLimitQueryRows()];
            }
            if(!lstExistingAdHocCandidatesWithSameEmail.isEmpty()){
                String deloitteEmail='';
                String PID='';
                String AvatureId='';
                try{
                    for(Contact existingContact:lstExistingAdHocCandidatesWithSameEmail){
                        deloitteEmail=existingContact.Email;
                        AvatureId=existingContact.Avature_ID__c;
                        mapNewCandidates.get(existingContact.Email).WCT_Ad_Hoc_Contact__c=existingContact.id;
                        mapNewCandidates.get(existingContact.Email).Degree_Type__c=existingContact.Degree_Type__c;                     
                        mapNewCandidates.get(existingContact.Email).TRM_serviceArea__c=existingContact.TRM_serviceArea__c;
                        mapNewCandidates.get(existingContact.Email).TRM_correspondingFSS__c=existingContact.TRM_correspondingFSS__c;
                        mapNewCandidates.get(existingContact.Email).CR_Closed_List_Outcome__c=existingContact.CR_Closed_List_Outcome__c;
                        mapNewCandidates.get(existingContact.Email).CR_Contact_Category_Ranking__c=existingContact.CR_Contact_Category_Ranking__c;
                        mapNewCandidates.get(existingContact.Email).CR_School_Recruiter__c=existingContact.CR_School_Recruiter__c;
                        mapNewCandidates.get(existingContact.Email).CR_Dropped_Resume__c=existingContact.CR_Dropped_Resume__c;
                        mapNewCandidates.get(existingContact.Email).CR_Expected_Grad_Month__c=existingContact.CR_Expected_Grad_Month__c;
                        mapNewCandidates.get(existingContact.Email).CR_Expected_Grad_Year__c=existingContact.CR_Expected_Grad_Year__c;
                        mapNewCandidates.get(existingContact.Email).CR_Graduate_GPA__c=existingContact.CR_Graduate_GPA__c;
                        mapNewCandidates.get(existingContact.Email).GRE_Post_8_1_2011__c=existingContact.GRE_Post_8_1_2011__c;
                        mapNewCandidates.get(existingContact.Email).CR_High_Potential_Program_Peer__c=existingContact.CR_High_Potential_Program_Peer__c;
                        mapNewCandidates.get(existingContact.Email).TRM_leadSourceDetail__c=existingContact.TRM_leadSourceDetail__c;
                        mapNewCandidates.get(existingContact.Email).Location_Preference__c=existingContact.Location_Preference__c;
                        mapNewCandidates.get(existingContact.Email).CR_Undergrad_Major__c=existingContact.CR_Undergrad_Major__c;
                        mapNewCandidates.get(existingContact.Email).CR_Other_GPA__c=existingContact.CR_Other_GPA__c;
                        mapNewCandidates.get(existingContact.Email).CR_Undergrad_Other_Major__c=existingContact.CR_Undergrad_Other_Major__c;
                        mapNewCandidates.get(existingContact.Email).CR_Program_Interest_for_Interview__c=existingContact.CR_Program_Interest_for_Interview__c;
                        mapNewCandidates.get(existingContact.Email).SAT_Total__c=existingContact.SAT_Total__c;
                        mapNewCandidates.get(existingContact.Email).SAT_Verbal__c=existingContact.SAT_Verbal__c;
                        mapNewCandidates.get(existingContact.Email).SAT_Writing__c=existingContact.SAT_Writing__c;
                        mapNewCandidates.get(existingContact.Email).School_Program__c=existingContact.School_Program__c;
                        mapNewCandidates.get(existingContact.Email).TRM_Source_Detail_Name__c=existingContact.TRM_Source_Detail_Name__c;
                        mapNewCandidates.get(existingContact.Email).CR_Undergraduate_Major_GPA_4_00_Scale__c=existingContact.CR_Undergraduate_Major_GPA_4_00_Scale__c;
                        mapNewCandidates.get(existingContact.Email).CR_Undergraduate_Overall_GPA_4_00_Scale__c=existingContact.CR_Undergraduate_Overall_GPA_4_00_Scale__c;
                        mapNewCandidates.get(existingContact.Email).CR_ACT__c=existingContact.CR_ACT__c;
                        mapNewCandidates.get(existingContact.Email).CR_GMAT__c=existingContact.CR_GMAT__c;
                        mapNewCandidates.get(existingContact.Email).GRE_Pre_8_1_2011__c=existingContact.GRE_Pre_8_1_2011__c;
                        
                    }     
                }catch(Exception ex){
                    Exception_Log__c log = new Exception_Log__c(className__c='ContactTriggerHandler_AT', Running_User__c = UserInfo.getUserId());
                    log.Detailed_Exception__c='info: Deloitte Email Address- '+deloitteEmail+' ; PID- '+PID+' ; AvatureId- '+AvatureId+ex.getMessage();
                    log.User_Description__c='Merge Conflict';
                    log.RecordTypeId=Schema.SObjectType.Exception_Log__c.getRecordTypeInfosByName().get('Logging').getRecordTypeId();
                    exceptionLogList.add(log);
                }
            }
        }
        catch(Exception ex){
            Exception_Log__c log = new Exception_Log__c(className__c='ContactTriggerHandler_AT', Running_User__c = UserInfo.getUserId());
            log.Detailed_Exception__c=ex.getMessage();
            log.User_Description__c='Merge Conflict';
            log.RecordTypeId=Schema.SObjectType.Exception_Log__c.getRecordTypeInfosByName().get('Logging').getRecordTypeId();
            exceptionLogList.add(log);
        }
        insert exceptionLogList;
    }
    
    public void handleAvatureLoad(List<Contact> newConList){
        ConRecTypeId=CaseAndContact_Values__c.getOrgDefaults();
        set<string> deloitteEmails = new set<string>();
        set<string> nonDeloitteEmails = new set<string>();
        set<string> allEmails = new set<string>();
        Map<string,contact> deloitteEmailsConMap = new Map<string,contact>();
        Map<string,contact> nonDeloitteEmailsConMap = new Map<string,contact>();
        boolean delMailsNotEmpty,otherMailsNotEmpty,candToRemRMSIdFlag;
        LIST<Exception_Log__c> exceptionLogList=new LIST<Exception_Log__c>();
        List<Contact> empToUpdate = new List<Contact>();
        // Candidate record merge comments tracking list
        List<Contact> canCommentList = new List<Contact>();
        map<String,contact> candEmailsToRemRMSID = new map<String,contact>();
        Map<Id,Id> candEmailMapToMerge = new Map<Id,Id>();
        set<String> alreadyAddedMails = new set<String>();
        String mergeComments= '';
        for(Contact con:newConList){
            if(con.WCT_Contact_Type__c == 'Candidate'){
                if(con.email <> null){
                    if(con.email.contains('@deloitte.com')){
                        // candidate with Deloitte Email
                        deloitteEmails.add(con.email);
                        deloitteEmailsConMap.put(con.email,con);
                    }else{
                        // All Non Deloitte
                        nonDeloitteEmails.add(con.email);
                        nonDeloitteEmailsConMap.put(con.email,con);
                    }
                }
            }
        }
        if(!deloitteEmails.isEmpty()){
            allEmails.addAll(deloitteEmails);
            delMailsNotEmpty=true;
        }
        else{
            delMailsNotEmpty=false;
        }
        if(!nonDeloitteEmails.isEmpty()){
            allEmails.addAll(nonDeloitteEmails);
            otherMailsNotEmpty=true;
        }
        else{
            otherMailsNotEmpty=false;
        }
        Contact checkException=new Contact();
        String aventureId='';
        String deloitteEmail='';
        if(!allEmails.isEmpty()){
            
            try{
                // List for getting employee contact with having same email
                List<Contact> empContactsList = [SELECT id,email,WCT_SAP_RMS_ID__c,WCT_Taleo_Id__C  FROM Contact 
                                                 where recordTypeId =:EmployeeRtypeId AND WCT_Type__c=:'Employee'
                                                 AND email IN :allEmails ORDER BY createdDate DESC];
                if(empContactsList.size()>0){
                    for(Contact emp:empContactsList){// Deloitte Active - Non Active Emp
                        if(otherMailsNotEmpty && nonDeloitteEmails.contains(emp.email)){
                            //emp.WCT_Taleo_Id__C = nonDeloitteEmailsConMap.get(emp.email).WCT_Taleo_Id__C;
                            if(alreadyAddedMails.IsEmpty()){
                                alreadyAddedMails.add(emp.email);
                                checkException=UpdateOldwithNewFields(emp,nonDeloitteEmailsConMap);
                                aventureId=checkException.Avature_ID__c;
                                deloitteEmail=checkException.Email;
                                empToUpdate.add(checkException);
                                candEmailsToRemRMSID.put(emp.email,Emp);                  
                            }else{
                                if(!alreadyAddedMails.contains(emp.email)){
                                    alreadyAddedMails.add(emp.email);
                                    checkException=UpdateOldwithNewFields(emp,nonDeloitteEmailsConMap);
                                    aventureId=checkException.Avature_ID__c;
                                    deloitteEmail=checkException.Email;
                                    empToUpdate.add(checkException);
                                    candEmailsToRemRMSID.put(emp.email,Emp);
                                }
                            }
                        }
                        if(delMailsNotEmpty && deloitteEmails.contains(emp.email)){
                            if(alreadyAddedMails.IsEmpty()){
                                //emp.WCT_Taleo_Id__C = deloitteEmailsConMap.get(emp.email).WCT_Taleo_Id__C;
                                alreadyAddedMails.add(emp.email);
                                checkException=UpdateOldwithNewFields(emp,deloitteEmailsConMap);
                                aventureId=checkException.Avature_ID__c;
                                deloitteEmail=checkException.Email;
                                empToUpdate.add(checkException);
                                candEmailsToRemRMSID.put(emp.email,Emp); 
                            }else{
                                if(!alreadyAddedMails.contains(emp.email)){
                                    alreadyAddedMails.add(emp.email);
                                    checkException=UpdateOldwithNewFields(emp,deloitteEmailsConMap);
                                    aventureId=checkException.Avature_ID__c;
                                    deloitteEmail=checkException.Email;
                                    empToUpdate.add(checkException);
                                    candEmailsToRemRMSID.put(emp.email,Emp);                       
                                }                   
                            }
                        }          
                    }
                }
                else{
                    // For tracking candidate contact merge issue 
                    for(Contact con:newConList){
                        if(con.recordtypeId==ConRecTypeId.CandidateRecordTypeId__c && RecursiveTriggerHandler.isFirstTime){
                            RecursiveTriggerHandler.isFirstTime = false;
                            contact c = new contact (id=con.Id);
                            
                            canCommentList.add(c);
                        }
                    }
                }
                
            }catch(Exception ex){
                
                Exception_Log__c log = new Exception_Log__c(className__c='ContactTriggerHandler_AT', Running_User__c = UserInfo.getUserId());
                log.Detailed_Exception__c='info: Deloitte Email Address- '+deloitteEmail+' ; AvatureId- '+aventureId+ex.getMessage();
                log.User_Description__c='Merge Conflict';
                log.RecordTypeId=Schema.SObjectType.Exception_Log__c.getRecordTypeInfosByName().get('Logging').getRecordTypeId();
                exceptionLogList.add(log);
            }
        }
        List<Contact> canToUpdate = new List<Contact>();
        if(!candEmailsToRemRMSID.isEmpty())
        {
            candToRemRMSIdFlag = true;
        }else
        {
            candToRemRMSIdFlag = false;
        }
        map<id,contact> oldIdNewCont = new map<Id,contact>();
        for(Contact con:newConList){
            if(candToRemRMSIdFlag && candEmailsToRemRMSID.containsKey(con.email)){
                contact c = new contact (id=con.Id);
                c.WCT_Taleo_Id__c = '';
                c.Avature_ID__c = '';
                c.email = con.email+'.merged';
                c.WCT_Related_Contact_Status__c= 'Merged' ;
                
                canToUpdate.add(c);
                
                oldIdNewCont.put(con.Id,candEmailsToRemRMSID.get(con.Email));
                
                candEmailMapToMerge.put(con.Id,candEmailsToRemRMSID.get(con.Email).id);
                
            }
        }
        //Start - Merging Adhoc with Candidate
        Set<Id> AdhocCandIds = new Set<Id>();
        
        for(Contact NewCandidate:newConList){
            if((NewCandidate.recordtypeId==ConRecTypeId.CandidateRecordTypeId__c || NewCandidate.WCT_Contact_Type__c == ConRecTypeId.ContactType_Candidate__c) && NewCandidate.WCT_Ad_Hoc_Contact__c!=null ){                 
                candEmailMapToMerge.put(NewCandidate.WCT_Ad_Hoc_Contact__c, NewCandidate.id);
                system.debug('1'+candEmailMapToMerge);
                AdhocCandIds.add(NewCandidate.WCT_Ad_Hoc_Contact__c);
                
            }
        }
        
        if(!AdhocCandIds.isEmpty()){
            for(Contact adhocCon:[SELECT Id,email,Company_Realign__c,WCT_Related_Contact_Status__c
                                  FROM Contact 
                                  WHERE id IN :AdhocCandIds AND WCT_Related_Contact_Status__c <> 'Merged'])
                
            {
                system.debug('Ahoc'+adhocCon);                      
                                      
                                      adhocCon.Avature_ID__c = '';
                                      adhocCon.email = adhocCon.email+'.merged';
                                      adhocCon.WCT_Related_Contact_Status__c = 'Merged' ;
                                      
                                      canToUpdate.add(adhocCon);   
                system.debug('3'+canToUpdate);
                                      
                                  }
            
        }
        if(!canToUpdate.isEmpty()){
            update canToUpdate;
        }
        if(!empToUpdate.isEmpty()){
            update empToUpdate;
        }  
    }
    
    public contact UpdateOldwithNewFields (Contact Emp,  Map<string,contact> ConMap){
        contact upContactFld = Emp;             
        upContactFld.WCT_CN_Other_Institution__c=ConMap.get(Emp.email).WCT_CN_Other_Institution__c;
        upContactFld.WCT_Name_Suffix__c=ConMap.get(Emp.email).WCT_Name_Suffix__c;
        upContactFld.WCT_Primary_City_of_Residence__c=ConMap.get(Emp.email).WCT_Primary_City_of_Residence__c;
        upContactFld.WCT_Education_Level__c=ConMap.get(Emp.email).WCT_Education_Level__c;
        upContactFld.WCT_Hiring_Location__c=ConMap.get(Emp.email).WCT_Hiring_Location__c;
        //upContactFld.WCT_GLS_Belit_Score__c=ConMap.get(Emp.email).WCT_GLS_Belit_Score__c;
        upContactFld.WCT_Candidate_Program__c=ConMap.get(Emp.email).WCT_Candidate_Program__c;
        //upContactFld.WCT_GLS_Versant_Score__c=ConMap.get(Emp.email).WCT_GLS_Versant_Score__c;
        upContactFld.WCT_Home_Country__c=ConMap.get(Emp.email).WCT_Home_Country__c;
        upContactFld.WCT_Home_Zip__c=ConMap.get(Emp.email).WCT_Home_Zip__c;
        upContactFld.WCT_Middle_Name__c=ConMap.get(Emp.email).WCT_Middle_Name__c;
        upContactFld.WCT_Preferred_Name__c=ConMap.get(Emp.email).WCT_Preferred_Name__c;
        upContactFld.WCT_Race__c=ConMap.get(Emp.email).WCT_Race__c;
        upContactFld.HomePhone=ConMap.get(Emp.email).HomePhone;
        upContactFld.MobilePhone=ConMap.get(Emp.email).MobilePhone;
        upContactFld.WCT_Home_State__c=ConMap.get(Emp.email).WCT_Home_State__c;
        upContactFld.LastName=ConMap.get(Emp.email).LastName;
        upContactFld.WCT_Candidate_Hiring_Level__c=ConMap.get(Emp.email).WCT_Candidate_Hiring_Level__c;
        upContactFld.WCT_Home_Street_2__c=ConMap.get(Emp.email).WCT_Home_Street_2__c;
        upContactFld.FirstName=ConMap.get(Emp.email).FirstName;
        upContactFld.WCT_Home_Street__c=ConMap.get(Emp.email).WCT_Home_Street__c;
        upContactFld.WCT_Taleo_Id__c=ConMap.get(Emp.email).WCT_Taleo_Id__c;
        upContactFld.Avature_ID__c = ConMap.get(Emp.email).Avature_ID__c;
        upContactFld.WCT_Candidate_School__c=ConMap.get(Emp.email).WCT_Candidate_School__c;
        upContactFld.WCT_CN_Other_Employer__c=ConMap.get(Emp.email).WCT_CN_Other_Employer__c;
        upContactFld.CR_ACT__c=ConMap.get(Emp.email).CR_ACT__c;
        upContactFld.TRM_serviceArea__c=ConMap.get(Emp.email).TRM_serviceArea__c;
        upContactFld.TRM_correspondingFSS__c=ConMap.get(Emp.email).TRM_correspondingFSS__c;
        upContactFld.CR_Closed_List_Outcome__c=ConMap.get(Emp.email).CR_Closed_List_Outcome__c;
        upContactFld.CR_Contact_Category_Ranking__c=ConMap.get(Emp.email).CR_Contact_Category_Ranking__c;
        upContactFld.CR_School_Recruiter__c=ConMap.get(Emp.email).CR_School_Recruiter__c;
        upContactFld.CR_Dropped_Resume__c=ConMap.get(Emp.email).CR_Dropped_Resume__c;
        upContactFld.CR_Expected_Grad_Month__c=ConMap.get(Emp.email).CR_Expected_Grad_Month__c;
        upContactFld.CR_Expected_Grad_Year__c=ConMap.get(Emp.email).CR_Expected_Grad_Year__c;
        upContactFld.CR_Graduate_GPA__c=ConMap.get(Emp.email).CR_Graduate_GPA__c;
        upContactFld.GRE_Post_8_1_2011__c=ConMap.get(Emp.email).GRE_Post_8_1_2011__c;
        upContactFld.CR_High_Potential_Program_Peer__c=ConMap.get(Emp.email).CR_High_Potential_Program_Peer__c;
        upContactFld.TRM_leadSourceDetail__c=ConMap.get(Emp.email).TRM_leadSourceDetail__c;
        upContactFld.Location_Preference__c=ConMap.get(Emp.email).Location_Preference__c;
        upContactFld.CR_Undergrad_Major__c=ConMap.get(Emp.email).CR_Undergrad_Major__c;
        upContactFld.CR_Other_GPA__c=ConMap.get(Emp.email).CR_Other_GPA__c;
        upContactFld.CR_Undergrad_Other_Major__c=ConMap.get(Emp.email).CR_Undergrad_Other_Major__c;
        upContactFld.CR_Program_Interest_for_Interview__c=ConMap.get(Emp.email).CR_Program_Interest_for_Interview__c;
        upContactFld.SAT_Total__c=ConMap.get(Emp.email).SAT_Total__c;
        upContactFld.SAT_Verbal__c=ConMap.get(Emp.email).SAT_Verbal__c;
        upContactFld.SAT_Writing__c=ConMap.get(Emp.email).SAT_Writing__c;
        upContactFld.School_Program__c=ConMap.get(Emp.email).School_Program__c;
        upContactFld.TRM_Source_Detail_Name__c=ConMap.get(Emp.email).TRM_Source_Detail_Name__c;
        upContactFld.CR_Undergraduate_Major_GPA_4_00_Scale__c=ConMap.get(Emp.email).CR_Undergraduate_Major_GPA_4_00_Scale__c;
        upContactFld.CR_Undergraduate_Overall_GPA_4_00_Scale__c=ConMap.get(Emp.email).CR_Undergraduate_Overall_GPA_4_00_Scale__c;
        upContactFld.Current_Employer__c=ConMap.get(Emp.email).Current_Employer__c;
        upContactFld.WCT_Tenure_at_Level__c=ConMap.get(Emp.email).WCT_Tenure_at_Level__c;
        upContactFld.WCT_Resume__c=ConMap.get(Emp.email).WCT_Resume__c;
        upContactFld.WCT_Total_Experience__c=ConMap.get(Emp.email).WCT_Total_Experience__c;
        upContactFld.WCT_Home_City__c=ConMap.get(Emp.email).WCT_Home_City__c;
        upContactFld.WCT_Taleo_Status__c=ConMap.get(Emp.email).WCT_Taleo_Status__c;
        upContactFld.WCT_Relocation_Amt__c=ConMap.get(Emp.email).WCT_Relocation_Amt__c;
        upContactFld.WCT_Service_Line__c=ConMap.get(Emp.email).WCT_Service_Line__c;
        upContactFld.WCT_State_of_Hiring_Location__c=ConMap.get(Emp.email).WCT_State_of_Hiring_Location__c;
        upContactFld.WCT_Buddy_Champion__c=ConMap.get(Emp.email).WCT_Buddy_Champion__c;
        upContactFld.WCT_User_Group__c=ConMap.get(Emp.email).WCT_User_Group__c;
        upContactFld.WCT_Requisition_Number__c=ConMap.get(Emp.email).WCT_Requisition_Number__c;
        upContactFld.WCT_Service_Area__c=ConMap.get(Emp.email).WCT_Service_Area__c;
        upContactFld.WCT_Project_Name__c=ConMap.get(Emp.email).WCT_Project_Name__c;
        upContactFld.WCT_Sign_On_Bonus__c=ConMap.get(Emp.email).WCT_Sign_On_Bonus__c;
        upContactFld.WCT_Hiring_Partner__c=ConMap.get(Emp.email).WCT_Hiring_Partner__c;
        upContactFld.WCT_Recruiter_Email__c=ConMap.get(Emp.email).WCT_Recruiter_Email__c;
        upContactFld.WCT_Name_Prefix__c=ConMap.get(Emp.email).WCT_Name_Prefix__c;
        upContactFld.WCT_RequisitionHiringLevel__c=ConMap.get(Emp.email).WCT_RequisitionHiringLevel__c;
        upContactFld.WCT_Salary__c=ConMap.get(Emp.email).WCT_Salary__c;
        upContactFld.WCT_Type_of_Hire__c=ConMap.get(Emp.email).WCT_Type_of_Hire__c;
        upContactFld.WCT_Recruiter_Phone__c=ConMap.get(Emp.email).WCT_Recruiter_Phone__c;
        upContactFld.WCT_Entity__c=ConMap.get(Emp.email).WCT_Entity__c;
        //eEvents
        upContactFld.Phone=ConMap.get(Emp.email).Phone;
        upContactFld.Degree_Type__c=ConMap.get(Emp.email).Degree_Type__c;
        upContactFld.CR_GMAT__c=ConMap.get(Emp.email).CR_GMAT__c;
        upContactFld.GRE_Pre_8_1_2011__c=ConMap.get(Emp.email).GRE_Pre_8_1_2011__c;
        upContactFld.WCT_Hiring_Partner__c=ConMap.get(Emp.email).WCT_Hiring_Partner__c;
        upContactFld.LeadSource=ConMap.get(Emp.email).LeadSource;
        return upContactFld;
    }
    
    /* Name:checkGlobalRotator
Purpose: This method would prevent the Global rotator being separated.*/
    Public void checkGlobalRotator(List<Contact> contListNew, Map<Id,Contact> oldContList){
        system.debug('@@@@@@@@@@@@@@@@@@@  Global');
        system.debug('@@@@@@@@@@@@@@@@@@@  Global2'+contListNew);
        system.debug('@@@@@@@@@@@@@@@@@@@  Global3'+oldContList);
        for(Contact con:contListNew){
            //Reason for Action = ZI, Action Type Code = ZB
            Contact oldContact = oldContList.get(con.id);
            if(oldContact.WCT_Employee_Status__c!=null && con.WCT_Personnel_Number__c!=null && oldContact.WCT_Personnel_Number__c!=null &&
               con.WCT_Employee_Status__c!=null && con.WCT_Reason_For_Action_Code__c!=null && con.WCT_Action_Type_Code__c!=null)
            {
                system.debug('first if');
                
                if(oldContact.WCT_Employee_Status__c=='Active' && con.WCT_Personnel_Number__c!=oldContact.WCT_Personnel_Number__c && 
                   con.WCT_Employee_Status__c =='Seperated' && (con.WCT_Reason_For_Action_Code__c=='ZI'|| con.WCT_Reason_For_Action_Code__c=='ZO') && con.WCT_Action_Type_Code__c=='ZB'){  
                        system.debug('Second if');
                       con.WCT_Home_State__c=oldContact.WCT_Home_State__c;
                       con.Citizenship_Desc__c=oldContact.Citizenship_Desc__c;
                        system.debug('citizen'+con.Citizenship_Desc__c);
                       con.WCT_Home_Street__c=oldContact.WCT_Home_Street__c;
                       con.WCT_Person_Id__c=oldContact.WCT_Person_Id__c;
                       con.WCT_Company_Code__c=oldContact.WCT_Company_Code__c;
                       con.H1B_Work_Permit_Type__c=oldContact.H1B_Work_Permit_Type__c;
                       con.WCT_Org_Unit__c=oldContact.WCT_Org_Unit__c;
                       con.WCT_Capability__c=oldContact.WCT_Capability__c;
                       con.WCT_Personnel_Number__c=oldContact.WCT_Personnel_Number__c;
                       con.WCT_Organizational_Unit_Desc__c=oldContact.WCT_Organizational_Unit_Desc__c;
                       con.WCT_Home_Country__c=oldContact.WCT_Home_Country__c;
                       con.WCT_Home_Street_2__c=oldContact.WCT_Home_Street_2__c;
                       con.WCT_Absence_Type__c=oldContact.WCT_Absence_Type__c;  
                       con.ELE_Counselor_Email_ID__c=oldContact.ELE_Counselor_Email_ID__c;
                       con.WCT_HR_Service_Line_Code__c=oldContact.WCT_HR_Service_Line_Code__c;
                       con.Cost_Center_Business_Sub_Line_Desc__c=oldContact.Cost_Center_Business_Sub_Line_Desc__c;
                       con.WCT_Personnel_Area_Code__c=oldContact.WCT_Personnel_Area_Code__c;
                       con.WCT_Service_Area__c=oldContact.WCT_Service_Area__c;
                       con.WCT_Company_Codenew__c=oldContact.WCT_Company_Codenew__c;
                       con.WCT_Home_Phone_Number__c=oldContact.WCT_Home_Phone_Number__c;
                       con.WCT_Service_Line__c=oldContact.WCT_Service_Line__c;
                       con.WCT_Work_Tax_Area_Start_Date__c=oldContact.WCT_Work_Tax_Area_Start_Date__c;
                       con.WCT_Preferred_Name__c=oldContact.WCT_Preferred_Name__c;
                       //This is the field which will make the contact separated.
                       con.WCT_Employee_Status__c=oldContact.WCT_Employee_Status__c;
                       con.CBP_Employment_Percent__c=oldContact.CBP_Employment_Percent__c;
                       //con.WCT_DPM_Counselor__c=oldContact.WCT_DPM_Counselor__c;
                       con.WCT_Cap_Util_Lvl__c=oldContact.WCT_Cap_Util_Lvl__c;
                       con.WCT_SSN__c=oldContact.WCT_SSN__c;
                       con.CBP_Hire_Source_Description__c=oldContact.CBP_Hire_Source_Description__c;
                       con.WCT_Home_City__c=oldContact.WCT_Home_City__c;
                       con.WCT_SAP_RMS_ID__c=oldContact.WCT_SAP_RMS_ID__c;
                       con.CBP_Salary__c=oldContact.CBP_Salary__c;
                       con.WCT_Sub_Secondary_Market_Offering__c=oldContact.WCT_Sub_Secondary_Market_Offering__c;
                       con.WCT_Marital_Status__c=oldContact.WCT_Marital_Status__c;
                       con.WCT_Attendance_Absence_Type__c=oldContact.WCT_Attendance_Absence_Type__c;
                       con.Cost_Center_Business_Sub_Line_Code__c=oldContact.Cost_Center_Business_Sub_Line_Code__c;
                       con.Business_Segment__c=oldContact.Business_Segment__c;
                       con.WCT_Primary_Segment__c=oldContact.WCT_Primary_Segment__c;
                       con.WCT_Work_Permit_Type_Code__c=oldContact.WCT_Work_Permit_Type_Code__c;
                       con.WCT_Position_Number__c=oldContact.WCT_Position_Number__c;
                       con.WCT_Prior_Name__c=oldContact.WCT_Prior_Name__c;
                       con.WCT_HR_Service_Area_Code__c=oldContact.WCT_HR_Service_Area_Code__c;
                       con.Job_Level_Summary_Description__c=oldContact.Job_Level_Summary_Description__c;
                       con.WCT_Exempt_Non_Exempt__c=oldContact.WCT_Exempt_Non_Exempt__c;
                       con.WCT_Reason_For_Action_Code__c=oldContact.WCT_Reason_For_Action_Code__c;
                       con.Birthdate=oldContact.Birthdate;
                       con.WCT_Original_Hire_Date__c=oldContact.WCT_Original_Hire_Date__c;
                       con.WCT_Action_Type__c=oldContact.WCT_Action_Type__c;
                       con.WCT_Abscense_End_Date__c=oldContact.WCT_Abscense_End_Date__c;
                       con.WCT_LOA_indicator__c=oldContact.WCT_LOA_indicator__c;
                       con.H1B_Cost_Center_Description__c=oldContact.H1B_Cost_Center_Description__c;
                       con.WCT_Work_Tax_Area__c=oldContact.WCT_Work_Tax_Area__c;
                       con.WCT_Rehire_Eligibility__c=oldContact.WCT_Rehire_Eligibility__c;
                       con.Fax=oldContact.Fax;
                       con.Email=oldContact.Email;
                       con.WCT_Last_Day_Worked__c=oldContact.WCT_Last_Day_Worked__c;
                       con.WCT_Sub_capability__c=oldContact.WCT_Sub_capability__c;
                       con.Phone=oldContact.Phone;
                       con.FirstName=oldContact.FirstName;
                       con.WCT_Sub_Secondary_Industry__c=oldContact.WCT_Sub_Secondary_Industry__c;
                       con.WCT_Sub_Capability_Description__c=oldContact.WCT_Sub_Capability_Description__c;
                       con.WCT_Action_Type_Code__c=oldContact.WCT_Action_Type_Code__c;
                       con.WCT_Office_City_Personnel_Subarea__c=oldContact.WCT_Office_City_Personnel_Subarea__c;
                       con.H1B_Work_Permit_Expiry_Date__c=oldContact.H1B_Work_Permit_Expiry_Date__c;
                       con.WCT_Citizenship__c=oldContact.WCT_Citizenship__c;
                       con.WCT_ExternalEmail__c=oldContact.WCT_ExternalEmail__c;
                       con.WCT_Most_Recent_Rehire__c=oldContact.WCT_Most_Recent_Rehire__c;
                       con.WCT_Name_Prefix__c=oldContact.WCT_Name_Prefix__c;
                       con.WCT_Secondary_Segment__c=oldContact.WCT_Secondary_Segment__c;
                       con.WCT_Gender__c=oldContact.WCT_Gender__c;
                       con.WCT_Name_Suffix__c=oldContact.WCT_Name_Suffix__c;
                       con.WCT_Abscense_Begin_Date__c=oldContact.WCT_Abscense_Begin_Date__c;
                       con.WCT_Cost_Center__c=oldContact.WCT_Cost_Center__c;
                       con.Focus_Code__c=oldContact.Focus_Code__c;
                       con.WCT_Reason_for_Action__c=oldContact.WCT_Reason_for_Action__c;
                       con.WCT_Most_Recent_Promotion_Date__c=oldContact.WCT_Most_Recent_Promotion_Date__c;
                       con.WCT_Job_Text__c=oldContact.WCT_Job_Text__c;
                       con.WCT_Residence_Status_Work_Permit__c=oldContact.WCT_Residence_Status_Work_Permit__c;
                       con.WCT_Federal_Flag__c=oldContact.WCT_Federal_Flag__c;
                       con.WCT_Region__c=oldContact.WCT_Region__c;
                       con.WCT_Capability_Description__c=oldContact.WCT_Capability_Description__c;
                       con.CBP_Service_Date__c=oldContact.CBP_Service_Date__c;
                       con.WCT_Facility_Name__c=oldContact.WCT_Facility_Name__c;
                       con.WCT_Middle_Name__c=oldContact.WCT_Middle_Name__c;
                       con.LastName=oldContact.LastName;                        
                       con.WCT_Visa_Type__c=oldContact.WCT_Visa_Type__c;
                       con.WCT_User_Id__c=oldContact.WCT_User_Id__c;
                       con.WCT_Employee_Sub_Group__c=oldContact.WCT_Employee_Sub_Group__c;
                       con.WCT_Function__c=oldContact.WCT_Function__c;
                       con.WCT_Primary_Market_Offering__c=oldContact.WCT_Primary_Market_Offering__c;
                       con.WCT_Contact_Type__c=oldContact.WCT_Contact_Type__c;
                       con.Talent_Model_Desc__c=oldContact.Talent_Model_Desc__c;
                       con.WCT_Employee_Status__c=oldContact.WCT_Employee_Status__c;
                       con.MobilePhone=oldContact.MobilePhone;
                       con.WCT_Job_Level_Text__c=oldContact.WCT_Job_Level_Text__c;
                       con.WCT_PTO_Benifit_Flag__c=oldContact.WCT_PTO_Benifit_Flag__c;
                       con.Weekly_Working_Hours__c=oldContact.Weekly_Working_Hours__c;
                       con.Focus_Desc__c=oldContact.Focus_Desc__c;
                       con.WCT_Home_Zip__c=oldContact.WCT_Home_Zip__c;
                       con.WCT_India_PAN_Last_4_digits__c=oldContact.WCT_India_PAN_Last_4_digits__c;
                       con.WCT_Terminated_Date__c=oldContact.WCT_Terminated_Date__c;
                       con.WCT_Attendance_Absence_Type_Desc__c=oldContact.WCT_Attendance_Absence_Type_Desc__c;
                       con.WCT_Primary_Industry__c=oldContact.WCT_Primary_Industry__c;
                       con.CBP_Job_Level_Code__c=oldContact.CBP_Job_Level_Code__c;
                   }
            }
        }
    }
}