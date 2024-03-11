/**********************************************************************************************************
* Author : Renee Chua
* Description:   This class configures the email content to be sent for Free Trial Request
***********************************************************************************************************/
public class EmailTemplateClass{
    
    public  static Map<String, String>          mapSErrorTR         {get;set;}
    public  static List<String>                 lstErrorReceiver    {get;set;}

    private static final String                 S_TR_EXPIRE         = 'ExpiredIn7Days';
    private static final String                 S_TR_TYPE_FT        = UtilityClass.getPickListValues(TrialRequest__c.Type__c.getDescribe(), 'Free Trial');
    private static final String                 S_TR_TYPE_POC       = UtilityClass.getPickListValues(TrialRequest__c.Type__c.getDescribe(), 'POC');
    private static final String                 S_TR_TYPE_TT        = UtilityClass.getPickListValues(TrialRequest__c.Type__c.getDescribe(), 'Training Trial');
    private static final String                 S_TR_TYPE_PROJ      = UtilityClass.getPickListValues(TrialRequest__c.Type__c.getDescribe(), 'Project');

    public EmailTemplateClass() {}

    /*******************************************************************************************************
    * @description  Generic method to trigger Email Sending on Salesforce Org
    ********************************************************************************************************/
    public static void prepareBulkUpdate(List<sObject> lstSObj){
        List<Messaging.SingleEmailMessage> lstMsgs  = new List<Messaging.SingleEmailMessage>();

        if(lstSObj != null && lstSObj.size() > 0){
            // STANDARD TRIAL REQUEST Email Sending
            if(lstSObj.getSObjectType() == TrialRequest__c.getSObjectType()){
                for(TrialRequest__c tr : (List<TrialRequest__c>)lstSObj){
                	lstMsgs.add(singleEmailMessageBuild(tr, ''));
                }
            }
        }

        // TRAINING TRIAL REQUEST ERROR Email Sending
        If(EmailTemplateClass.mapSErrorTR != null && EmailTemplateClass.mapSErrorTR.size() > 0){
            lstMsgs.add(constructAllErrorEmails('TR-Error-Manager'));
            lstMsgs.add(constructAllErrorEmails('TR-Error-Requestor'));
        }

        if(!lstMsgs.isEmpty()){
          Messaging.SendEmailResult[] results = Messaging.sendEmail(lstMsgs);
          if( !results.isEmpty() ){
            if (results[0].success) {
              System.debug('######################### The email was sent successfully.');
            } else {
              System.debug('######################### The email failed to send: ' + results[0].errors[0].message);
            }
          }
          else{
            System.debug('######################### The email failed to send.');
          }
        }
    }

    /*******************************************************************************************************
    * @description  Construct a single Messaging.SingleEmailMessage
    **************************************************************************************************************************/
    private static Messaging.SingleEmailMessage singleEmailMessageBuild(sObject sObj, String sOOB_Event){
        List<String> lstToReceivr           = new List<String>();
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        List<Document> lstDocs = UtilityClass.getTermsAndCondDocId();
        String sSubject;

        // To Address & CC Address
        if(sObj.getSObjectType() == Schema.TrialRequest__c.getSObjectType()){
            TrialRequest__c sObjTR = (TrialRequest__c) SObj;
            lstToReceivr.add(Class.ADR_WEBEVAL);
    
            // Notification for Free Trial
            if(sObjTR.Type__c == S_TR_TYPE_FT && lstDocs.size() > 0 ){
		If (sObjTR.Language__c == 'FR') 
		   sSubject = sObjTR.Contact__r.Account.Corporate_Name__c+': Votre demande d’essai de 30 jours ';
		Else 
		   sSubject = sObjTR.Contact__r.Account.Corporate_Name__c+': Your  30-day free trial request';
		msg.setEntityAttachments(new List<String>{String.valueOf(lstDocs[0].Id)});
            }
            // Notification for POC
            else if(sObjTR.Type__c == S_TR_TYPE_POC && sObjTR.POC_T_C_Accepted__c == true){
                sSubject = sObjTR.Contact__r.Account.Corporate_Name__c+': Your  PoC access';
            	}
		else if(sObjTR.Type__c == S_TR_TYPE_PROJ){
                	sSubject = sObjTR.Contact__r.Account.Corporate_Name__c+': Your  Project Platform';
            	}
 
            // ADD Internal Recipients
            if(sObjTR.SalesRepresentative__c != null && sObjTR.SalesRepresentative__r.Email != null){
                lstToReceivr.add(sObjTR.SalesRepresentative__r.Email);
            }
	    if(sObjTR.Account_SDR__c != null && sObjTR.Account_SDR__r.Email != null){
                lstToReceivr.add(sObjTR.Account_SDR__r.Email);
            }
            if(sObjTR.Contact__c != null && sObjTR.Contact__r.Owner.Email != null){
                lstToReceivr.add(sObjTR.Contact__r.Owner.Email);
            }
	    if(sObjTR.ServicesDirector__c != null && sObjTR.ServicesDirector__r.Email != null){
                lstToReceivr.add(sObjTR.ServicesDirector__r.Email);
            }
            if(sObjTR.ProductEngineer__c != null && sObjTR.ProductEngineer__r.Email != null){
                lstToReceivr.add(sObjTR.ProductEngineer__r.Email);
            }



	// Change to send reminder email to prospect if IsDotNotSendInitalEmail__c is true
        if(sObjTR.Contact__c != null &&  sObjTR.Contact__r.Email != null) {
	   if ((sObjTR.Type__c == S_TR_TYPE_POC && !sObjTR.IsDotNotSendInitalEmail__c) || sObjTR.Type__c == S_TR_TYPE_FT ){
                msg.toAddresses     = new String[] {(String)sObjTR.Contact__r.Email};
                msg.ccAddresses     = lstToReceivr;
           }			 
	   else {
		msg.toAddresses     = lstToReceivr;} 
           }          				
        }
 
        msg.setSubject(sSubject);
        msg.setHtmlBody(htmlBodyBuild(sObj, sOOB_Event));
        msg.setCharset('UTF-8');
        msg.OrgWideEmailAddressId = UtilityClass.getOrgWideEmailAddr(Class.ADR_NOREPLY_E)[0].Id;
        return msg;
    }

 
    /**************************************************************************************************************************************************************************************************
    ****************************************************************************************  HTML Email Body  ****************************************************************************************
    /**************************************************************************************************************************************************************************************************/

   
    private static string htmlBodyBuild(SObject sObj, String sOOB_Event){
        String sHtmlBody;
	string pword ;

       
        if(sObj.getSObjectType() == Schema.TrialRequest__c.getSObjectType()){
            TrialRequest__c sObjTR = (TrialRequest__c) SObj;


			
	// HEADER
        sHtmlBody           = '<html><head><meta content="text/html;charset=utf-8" http-equiv="Content-Type"/>';
        sHtmlBody           +='<meta content="initial-scale=1.0" name="viewport"/>';
        sHtmlBody           +='<meta content="telephone=no" name="format-detection"/>';
        sHtmlBody           +='<title> International</title>';
        
	// CSS
        sHtmlBody           +='<style type="text/css">.ReadMsgBody { width: 100%; background-color: #f5f8fa;}.ExternalClass {width: 100%; background-color: #f5f8fa;}.ExternalClass, .ExternalClass p, .ExternalClass span, .ExternalClass font, .ExternalClass td, .ExternalClass div {line-height:100%;}';
	
	//TAGs CLASSES
        sHtmlBody           +='body {-webkit-text-size-adjust:none; -ms-text-size-adjust:none;}body {margin:0; padding:0;}table {border-spacing:0;}table td {border-collapse:collapse;}.yshortcuts a {border-bottom: none !important;}</style>';
	sHtmlBody           +='</head>';
            
	// BODY

	sHtmlBody           +='<body bgcolor="#f5f8fa" style="margin:0; padding:20px 0;"><table border="0" cellpadding="0" cellspacing="0" style="background-color: #f5f8fa; width: 100%;" width="840">';
	sHtmlBody           +='<tbody><tr><td align="center" style="padding:30px;background-color: #f5f8fa;" valign="top"><table border="0" cellpadding="0" cellspacing="0" class="container" style="background-color: #ffffff; width: 550px;" width="550">';
	sHtmlBody           +='<tbody><tr><td align="left" class="container-padding-left" style="padding: 30px" valign="top">';

			

 
	// BODY for Type POC or FREE TRIAL for both EN(English) and FR(French) Template
			
	if(sObjTR.Type__c == S_TR_TYPE_FT && sObjTR.Language__c == 'FR') {
		sHtmlBody +='<div style="font-family:Verdana; font-size:18px; color:#31B672; line-height: 17px; font-weight: bold">Votre demande d’essai de 30 jours avec </div>&nbsp;<br/><br/>';
		sHtmlBody +='<div style="font-family:Verdana; font-size:13px; color:#22354b; line-height: 17px"><strong>Bonjour ' +  sObjTR.Salutation_and_Last_Name__c + ',</strong><br><br>';
		sHtmlBody +='Nous vous remercions pour votre demande d’essai gratuit de notre plateforme . Vous avez 30 jours pour tester la solution, et ce dès maintenant ! <br><br>';
		sHtmlBody +='Notez que votre accès sera disponible jusqu\'au ' +UtilityClass.getFormatedDataCORP(sObjTR.EndDate__c)+ '. Voici quelques informations importantes pour débuter :';
		sHtmlBody += '<ul><li>Rendez-vous sur la page de connexion : <a href="' + sObjTR.URLAccess__c + '" class="insideATable" style="color: #31B672; font-weight: bold">'+ sObjTR.URLAccess__c + '</a><br>&nbsp;</li>';
		sHtmlBody += '<li>Entrez votre identifiant, votre mot de passe et votre<br> environnement :</li>';
	}
	else 
		if (sObjTR.Type__c == S_TR_TYPE_PROJ) {
			sHtmlBody +='<br/><div style="font-family:Verdana; font-size:18px; color:#31B672; line-height: 17px; font-weight: Bold">';
			sHtmlBody += 'Your  Project Platform' + '</div>&nbsp;<br/><br/><div style="font-family:Verdana; font-size:13px; color:#22354b; line-height: 17px"><strong>Hi ' + sObjTR.Salutation_and_Last_Name__c + '</strong>,<br /><br />';
			sHtmlBody += 'Thank you for trying , your project access starts today!<br /><br /> ';
			sHtmlBody += 'Here is some important information about your access available until '+UtilityClass.getFormatedDataCORP(sObjTR.EndDate__c)+':';
		}
		else {
			sHtmlBody +='<br/><div style="font-family:Verdana; font-size:18px; color:#31B672; line-height: 17px; font-weight: Bold">';
			sHtmlBody += 'Your  ' + (sObjTR.Type__c == S_TR_TYPE_POC ? 'Proof of Concept' : 'free 30-day trial request') + '</div>&nbsp;<br/><br/><div style="font-family:Verdana; font-size:13px; color:#22354b; line-height: 17px"><strong>Hi ' + sObjTR.Salutation_and_Last_Name__c + '</strong>,<br /><br />';
			sHtmlBody += 'Thank you for trying , your ' + + (sObjTR.Type__c == S_TR_TYPE_POC ? 'PoC access' : ' 30-day free trial') + ' starts today!<br /><br /> ';
			sHtmlBody += 'Here is some important information about your ' + (sObjTR.Type__c == S_TR_TYPE_POC ? 'access' :  'trial') +  ' available until '+UtilityClass.getFormatedDataCORP(sObjTR.EndDate__c)+':';
		}

		if(sObjTR.Type__c == S_TR_TYPE_FT) {
			If (sObjTR.Language__c != 'FR') {
				sHtmlBody += '<ul><li>Go to your login page: <a href="' + sObjTR.URLAccess__c + '" class="insideATable" style="color: #31B672; font-weight: bold">' + sObjTR.URLAccess__c + '</a><br>&nbsp;</li>';
				sHtmlBody += '<li>Enter your login, password and environment:</li>';
			}
		}
		else {
			sHtmlBody += '<ul><li>Go to your login page: <a href="' + sObjTR.URL_Access__c + '" class="insideATable" style="color: #31B672; font-weight: bold">' + sObjTR.URL_Access__c + '</a><br>&nbsp;</li>';
			sHtmlBody += '<li>Enter your login and password:</li>';
		}
                    
		if(sObjTR.TrialLogins__r != null && !sObjTR.TrialLogins__r.isEmpty()){		
			integer i = 0;
			for(TrialLogin__c tl : sObjTR.TrialLogins__r){
				i = i + 1;
				if (i == 1) {
					sHtmlBody +='<ul><li>';	}
				else {
					sHtmlBody +='</li><li>';
				}
				sHtmlBody +='</li><li>';
			}
			sHtmlBody +='<strong>' + tl.User__r.Products__c + '</strong> : ' + tl.CustomUserName__c ;
			If(sObjTR.Type__c == S_TR_TYPE_FT) 
				pword = sObjTR.Free_Trial_Password__c;		
			else  pword = sObjTR._user_password__c;	
			}
					
			sHtmlBody +='<br/>&nbsp;</li><li><strong>Password</strong> : ' + pword + '</li>';
			If(sObjTR.Type__c == S_TR_TYPE_FT) 
				sHtmlBody +='<li><strong>Environment</strong> : ' + sObjTR.Environment__r.Name + '</li></ul></li></ul>';
			else sHtmlBody +='</ul></li></ul>';					 	
			}
			if(sObjTR.Type__c == S_TR_TYPE_FT && sObjTR.Language__c == 'FR') {
				sHtmlBody +='Pour faciliter votre prise en main de la solution, nous vous invitons à regarder nos <a href="https://community.com/t5/-How-To-Videos-French/bd-p/how-to-video?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp" style="color: #31B672; font-weight: bold">vidéos tutorielles</a>. <br><br>';
				sHtmlBody +='Pendant votre période d\'essai, nous vous invitons également à rejoindre la <a href="https://community.com/?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp" style="color: #31B672; font-weight: bold">Communauté ME</a> ';
				sHtmlBody +='pour obtenir des informations complémentaires sur  et échanger avec notre communauté internationale d’utilisateurs. <br/>';
				sHtmlBody +='Nous vous remercions encore de votre confiance, et nous vous souhaitons une très belle expérience avec  durant ces 30 prochains jours.  <br><br>';
			}
			else {
				sHtmlBody +='To learn more about , you can visit our tutorial web page where you will find <a href="https://community.com/t5/How-To-Videos-English/ct-p/howto-video-cat?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp" style="color: #31B672; font-weight: bold">how-to videos</a>.<br/><br/>';
				sHtmlBody +='During the ' + (sObjTR.Type__c == S_TR_TYPE_POC ? 'PoC' :  'trial') + ', we also invite you to join ';
				sHtmlBody +='<a href="https://community.com/?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp" style="color: #31B672; font-weight: bold"> Community</a> ';
				sHtmlBody +='to get additional information about  and share your experience with other  users worldwide.<br/><br/> ';
				sHtmlBody +='Thank you again for trying !</p><br /> ';
			}

		
			// SIGNATURE CONTENT
			if(sObjTR.Type__c == S_TR_TYPE_FT && sObjTR.Language__c == 'FR')
				sHtmlBody +='Bien cordialement,<br><br>';
			else
				sHtmlBody +='Best regards,<br><br>';

			sHtmlBody +='<span style="color: #31b672; font-weight: bold; font-size: 15px; line-height: 25px"> International</span><br>';
			sHtmlBody +='<span style="font-size: 11px">9 avenue René Coty – 75014 Paris – France<br>';
			
			// FOOTER 
			sHtmlBody +='<tr><td bgcolor="#22354B" align="center"  style="padding-left: 30px;padding-right: 30px;padding-top: 10px;padding-bottom: 10px" valign="top"><table width="490" border="0" cellspacing="0" cellpadding="0">';
			sHtmlBody +='<tbody><tr><td rowspan="2" width="80px"><a href="https://www.ME.com/?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp">';
			sHtmlBody +='<img alt="ME" src="https://www2.ME.com/l/62412/2019-11-27/3s31f7s/62412/194233/Picto_Footer_Logo_ME.png"></a></td>';
			sHtmlBody +='<td valign="middle" height="40px"><table align="center" border="0" cellpadding="0" cellspacing="0" style="padding-bottom: 10px; padding-top: 10px;"><tbody>';
			sHtmlBody +='<tr><td align="left" style="padding-right: 20px;" valign="middle"><a href="http://www2.ME.com/linkedin"><img alt="LinkedIn" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f4v/62412/194223/Picto_Footer_LinkedIn.png" style="display: block; border: 0 none;" width="25px"></a></td>';
			sHtmlBody +='<td align="left" style="padding-right: 20px;" valign="middle"><a href="http://www2.ME.com/twitter"><img alt="Twitter" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f4s/62412/194225/Picto_Footer_Twitter.png" style="display: block; border: 0 none;" width="25px"></a></td>';
			sHtmlBody +='<td align="left" style="padding-right: 20px;" valign="middle"><a href="http://www2.ME.com/youtube"><img alt="YouTube" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f4x/62412/194227/Picto_Footer_Youtube.png" style="display: block; border: 0 none;" width="25px"></a></td>';
			sHtmlBody +='<td align="left" style="padding-right: 20px;" valign="middle"><a href="https://www2.ME.com/facebook"><img alt="Facebook" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f4q/62412/194221/Picto_Footer_Facebook.png" style="display: block; border: 0 none;" width="25px"></a></td>';
			sHtmlBody +='<td align="left" style="padding-right: 20px;" valign="middle"><a href="https://www2.ME.com/facebook"><img alt="Facebook" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f4q/62412/194221/Picto_Footer_Facebook.png" style="display: block; border: 0 none;" width="25px"></a></td>';
			sHtmlBody +='<td align="left" valign="middle"><a href="https://community.ME.com/?utm_source=salesforce-email&utm_medium=email&utm_campaign=corp"><img alt="Community" border="0" src="https://www2.ME.com/l/62412/2019-11-27/3s31f52/62412/194229/Picto_Footer_Community.png" style="display: block; border: 0 none;"></a></td></tr></tbody></table></td></tr>';
			sHtmlBody +='<tr><td align="center" valign="middle" height="40px"><div style="font-size: 10px; font-family: Verdana; color:#FFFFFF"><a href="https://www.ME.com/en/legal-information?utm_medium=email&utm_source=salesforce-email&utm_campaign=corp" style="color: #ffffff; text-decoration: none;">Legal Information</a>&nbsp;|&nbsp;';
			sHtmlBody +='<a href="https://www.ME.com/en/privacy-policy?utm_medium=email&utm_source=pardot-email&utm_campaign=corp" style="color: #ffffff; text-decoration: none;">Privacy Policy</a>&nbsp;|&nbsp;';
			sHtmlBody +='<a href="https://www.ME.com/en/contact-us?utm_medium=email&utm_source=pardot-email&utm_campaign=corp" style="color: #ffffff; text-decoration: none;">Contact Us</a><br>&nbsp;</div></td></tr>';

			// SUBFOOTER
			sHtmlBody +='<tr><td colspan="2" style="padding: 15px"><div style="font-family:Verdana; font-size:10px; color:#ffffff; text-align: center">© ME International, 1994 - 2020. All rights reserved. </div></td></tr>';
			sHtmlBody +='</tbody></table></td></tr></tbody></table></td></tr></tbody></table></body></html>';	
			
	    }
        return sHtmlBody;
    }
}
