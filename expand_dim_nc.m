function [rc] = expand_dim_nc(filename,dimension_name,new_length)
%expand_dim_nc - expands limited dimension in the netCDF file and appends
%zeros to all variables that use that dimension
%   filename       - existing file (new one will get _ext suffix
%   dimension_name - dimension to expand
%   new_length     - length to which dimension should be expanded


fname=filename;
fname_new=[fname(1:end-3),'_ext.nc'];
dimname=dimension_name;
new_len=new_length;
%% find dimension
nci=ncinfo(fname); %get structure of the nc file

for i = 1:length(nci.Dimensions)
  if strcmp(nci.Dimensions(i).Name,dimname)
    ndcmpmax_i=i;
  end
end

%% get old dimension length and handle errors
old_len=nci.Dimensions(ndcmpmax_i).Length;
if old_len>new_len
  disp('new dimension length is too low')
  disp(['old size: ',num2str(old_len),...
        ' new size: ',num2str(new_len)]);
 return
end
%% structure for adjusted variables
vars_ndicomp=struct('index',[],'dim_index',[],'name',{},'size',[],'old_size',[],'data',[],'old_data',[],'data_check',[]);
%% get variables with specified dimension used.
n=0;
new_nci=nci;
for i = 1:length(nci.Variables) % loop through all variables
  has_dim=0;
       % if strcmp(nci.Variables(i).Datatype,'double')
       % new_nci.Variables(i).FillValue=double(1.e36);%nci.Variables(i).FillValue; 
       % elseif strcmp(nci.Variables(i).Datatype,'single')
       %   new_nci.Variables(i).FillValue=single(1.e36);
       % elseif strcmp(nci.Variables(i).Datatype,'int32')
       %   new_nci.Variables(i).FillValue=int32(1.e36);
       % elseif strcmp(nci.Variables(i).Datatype,'int16')
       % new_nci.Variables(i).FillValue=int16(1.e36);
       % elseif strcmp(nci.Variables(i).Datatype,'char')
       % new_nci.Variables(i).FillValue=' ';
       % end
  if ( ~isempty(nci.Variables(i).Dimensions)) % if not scalar
    for j=1:length(nci.Variables(i).Dimensions) %find needed dimension
      if strcmp(nci.Variables(i).Dimensions(j).Name,dimname)
      has_dim=1;
      dim_i=j;
      end
    end
    if has_dim == 1
        n=n+1;
        vars_ndicomp(n,1).index=i; %get var specs
        vars_ndicomp(n,1).name=nci.Variables(i).Name; 
        vars_ndicomp(n,1).old_size=nci.Variables(i).Size;
        tmp=ncread(fname,nci.Variables(i).Name);
        vars_ndicomp(n,1).old_data=tmp;
        sz=size(tmp);
        bsh=length(sz)-dim_i; % record how much we need to shift back
        tmp=shiftdim(tmp,dim_i); % shift array dims to make dim_i last
        sz=size(tmp); % get new size
        sz_add=sz; 
        sz_add(end)=1; % last dim of what we append should be 1
        for l = old_len+1:new_len % append zeros
          tmp2=zeros(sz_add);
          tmp=cat(length(sz),tmp,tmp2);
        end
        tmp=shiftdim(tmp,bsh); % shift dimensions back
        tmp=squeeze(tmp); % squeeze just in case
        sz=size(tmp);
        if(sz(end)==1 && length(sz) == 2 && dim_i == 1)
          sz=length(tmp); % need this for when var has only 1 dimesion
        end
        vars_ndicomp(n,1).size=sz; % record new size and data    
        vars_ndicomp(n,1).data=tmp;
        vars_ndicomp(n,1).dim_index=dim_i;
        
    end
  end
end
%% make new schema and adjust


new_nci.Dimensions(ndcmpmax_i).Length=new_len; % fix dim length

for i = 1:length(vars_ndicomp) % fix size and dim length for variables
  new_nci.Variables(vars_ndicomp(i).index).Size=vars_ndicomp(i).size;
  new_nci.Variables(vars_ndicomp(i).index).Dimensions(vars_ndicomp(i).dim_index).Length=new_len;

end

ncid=netcdf.create(fname_new,'NETCDF4'); %create new file and write in the schema
netcdf.close(ncid);
new_nci.Filename=strrep(new_nci.Filename,fname,fname_new);
new_nci.Format='NETCDF4';
ncwriteschema(fname_new,new_nci);

%% write vars into the new file
var_ids=zeros(length(vars_ndicomp),1);
for i = 1:length(vars_ndicomp)
   var_ids(i)=vars_ndicomp(i).index;
end

for i = 1:length(new_nci.Variables)
  tmp = ncread(fname,nci.Variables(i).Name);
  j=find(var_ids == i);
  if ~isempty(j)
    tmp=vars_ndicomp(j).data;
  end
    ncwrite(fname_new,nci.Variables(i).Name,tmp);
end
%% read data to check
nci_check=ncinfo(fname_new); %schema for checking

for i = 1:length(vars_ndicomp)
      vars_ndicomp(i).data_check=ncread(fname_new,vars_ndicomp(i).name);
      if ~all(vars_ndicomp(i).data_check == vars_ndicomp(i).data)
        disp('Data written into new file does not match data inputed')
      end
end





end

