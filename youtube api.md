# YOUTUBE API URLS  

## Search
```curl
https://www.youtube.com/results             BASE URL
?q=                                         QUERY
&page=                                      PAGE

&sp=EgIQAVAU                                FOR STREAM
&sp=EgIQAlAU                                FOR CHANNEL
&sp=EgIQA1AU                                FOR PLAYLIST
```

## Channel
```curl
https://www.youtube.com/feeds/videos.xml    BASE URL
?channel_id=                                CHANNEL ID

https://www.youtube.com/channel/:ID/videos  CLEAN URL

?view=0                                     VIDEO PARAMS
&flow=list                                  |
&sort=dd                                    |
&live_view=10000                            |
```

## Stream
```curl
https://www.youtube.com/get_video_info      BSAE URL
?video_id=                                  VIDEO_ID
&el=info
&ps=default
&eurl=
&gl=US
&hl=en

https://www.youtube.com/embed/:ID


https://www.youtube.com/get_video_info?video_id= + video_id +
            &el=info&ps=default&eurl=&gl=US&hl=en

```

Pulled from [here](https://github.com/TeamNewPipe/NewPipeExtractor/tree/master/src/main/java/org/schabi/newpipe/extractor/services/youtube)

---

```
ctoken EhgSBmNvbG9ycxoOU0l3QlVCVHFBd0ElM0QYvN7oGA%253D%253D  
itct   CBoQuy8iEwjrn57J94vWAhXFn64KHUCuBss%3D  

ctoken EhoSBmNvbG9ycxoQU0ZCUUZPb0RBQSUzRCUzRBi83ugY  
itct   CBoQuy8iEwj4g4TF94vWAhUBZq4KHdF7DWs%3D  

ctoken EhoSBmNvbG9ycxoQU0dSUUZPb0RBQSUzRCUzRBi83ugY  
itct   CBoQuy8iEwierb_G94vWAhUTdq4KHcWVCTI%3D  

ctoken EhoSBmNvbG9ycxoQU0hoUUZPb0RBQSUzRCUzRBi83ugY  
itct   CBoQuy8iEwiZwfvH94vWAhXCiq4KHa82A70%3D  

ctoken EhoSBmNvbG9ycxoQU0JSUUZPb0RBQSUzRCUzRBi83ugY  
itct   CD0Quy8YACITCOKdxPf2i9YCFVBOrgodqy8K0Cj0JA%3D%3D  



       Hex 12 1a 12 06
       Hex 12 18 12 06
       Padding?
       |    Query: colors                 
       |    |                            
ctoken EhgS BmNvbG9ycx oOU0 l3 QlVCVHFBd0ElM0QYvN7oGA%253D%253D  
ctoken EhoS BmNvbG9ycx oQU0 ZC UUZPb0RBQSUzRCUzRBi83ugY  
ctoken EhoS BmNvbG9ycx oQU0 dS UUZPb0RBQSUzRCUzRBi83ugY  
ctoken EhoS BmNvbG9ycx oQU0 ho UUZPb0RBQSUzRCUzRBi83ugY  
ctoken EhoS BmNvbG9ycx oQU0 JS UUZPb0RBQSUzRCUzRBi83ugY  

itct   CBoQuy8iEw jrn57J 94vWAh XFn 64KH UCuBss%3D  
itct   CBoQuy8iEw j4g4TF 94vWAh UBZ q4KH dF7DWs%3D  
itct   CBoQuy8iEw ierb_G 94vWAh UTd q4KH cWVCTI%3D  
itct   CBoQuy8iEw iZwfvH 94vWAh XCi q4KH a82A70%3D  
itct   CD0Quy8YAC ITCOKd xPf2i9 YCF VBOr godqy8K0Cj0JA%3D%3D  
```
