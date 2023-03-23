
***Approaches:***
1) Depict dataflow in c programs and how it is transformed with new commits , example: 

```C++
 int sum(int k) {
  if (k > 0) {
    return k + sum(k - 1);
  } else {
    return 0;
  }
}

int main() {
  int result = sum(10);
  cout << result;
  return 0;
}

```

the following code churns out this graph: 
     
     
  ![codeflow](./cflow0.png)
  
parsing patches of code and determining code profiles


   ![fn_parse](./fnparse.png)
   
parsing and collecting the apis generally used for users profile


  ![api_parse](./apiparse.png)
  
  
profile 

 ![profile](./profile.png)


exploratory data analysis plotting frequent pattern of commmits


   ![freq](freq.png)

EDA finding out domains names from email adress


   ![emails](emails.png)


  
  
  
  

