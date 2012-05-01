function [w,svmobj] = svmlsq(y,x,lambda,w)
%Compute optimal solution for hinge-squared SVM problem
%By guessing the support vectors, solving a least-squares
%optimization problem, then iterating between updating the support
%vectors and re-solving LSQ
%NOTE: works for L2-loss svms and makes sure bias is not
%regularized
% Input
%  y: vector of classes
%  x: data matrix
%  lambda: regulariation parameters
%  w: current estimate of w
%Tomasz Malisiewicz (tomasz@csail.mit.edu)


%maximum number of newton iterations
NITER = 20;

lambdaI = lambda*eye(size(x,1));

%b = ones(1,size(x,1));
%b(end) = 0;
%BtB = lambda*diag(b.^2);
%BtBinv = 1/lambda*diag(1./(b.^2));
%BtBinv(end) = 0;

F = size(x,1);
if ~exist('w','var')
  w = zeros(F+1,1);
end
oldw = w;
nostart = (sum(w(1:end-1).^2)==0);
oldgoods = [];
curmat = zeros(F,F);

oldobj =  lambda/2*sum(w(1:end-1).^2) + sum(hinge(y'.*(w(1:end-1)'*x+w(end))));
fprintf(1,' -++curobj=%.3f\n',oldobj)

for i = 1:NITER
  starttime=tic;
  if (i == 1) && (~exist('w','var') || sum(abs(w(:)))==0)
    %goods = randperm(length(y));
    %goods = goods(1:min(length(goods),100));
    %goods = unique([goods'; find(y==1)]);
    goods = 1:length(y);
  else
    r = (y'.*(w(1:end-1)'*x+w(end)));

    % [aa,bb] = sort(r,'ascend');
    % aa = aa(1:i*500);
    % bb = bb(1:i*500);
    % goods = bb(aa<=1);

    %choose all of them
    goods = find(r<=1.0);
  end
  
  newgoods = setdiff(goods,oldgoods);
  oldgoods = setdiff(oldgoods,goods);
  curmat = curmat + x(:,newgoods)*x(:,newgoods)' - x(:,oldgoods)*x(:,oldgoods)';
  %M = (BtB+2*curmat);
  %U = 2*x(:,goods)*y(goods);
  
  sx = sum(x(:,goods),2);
  M = [lambdaI + 2*curmat 2*sx;...
       sx' length(goods)];
  U = [2*x(:,goods)*y(goods); sum(y(goods))];

  % if i <= 3
  %   grad = M*w+U;
  %   w = w + .00001*grad;
  % else
  w = M\U;  
  %end

  
  

  %perform the line search  
  [w,bestobj] = line_search(w,oldw,y,x,lambda,linspace(0,1,10));
    

  if (oldobj - bestobj)/oldobj < .0001
    break;
  end
  oldw = w;  
  
  %svmobj =  lambda/2*sum(w(1:end-1).^2) + sum(hinge(y'.*(w'*x)));
  endtime = toc(starttime);
  fprintf(1,' ---curobj=%.3f (iter in %.3f s, +s: %d -s: %d)\n',...
          bestobj,endtime,length(newgoods),length(oldgoods));

  oldobj = bestobj;
  oldgoods = goods;
end

if nargout == 2
  svmobj = bestobj;
  %svmobj =  lambda/2*sum(w(1:end-1).^2) + sum(hinge(y'.*(w'*x)));
  %fprintf(1,'curobj=%.3f\n',svmobj);
end

%oldobj =  lambda/2*sum(w(1:end-1).^2) + sum(hinge(y'.*(w'*x)));


function [gw] = compute_gradient(y,x,w,lambda)

%Compute the w-norm part
gw = lambda*w;
gw(end) = 0;

%compute the w on positives part
r = y'.*(w'*x);
u = find(r<1);

for i = 1:length(u)
  gw = gw + hingeprime(r(u(i)))*y(u(i))*x(:,u(i));
end

function [w,bestobj] = line_search(w,oldw,y,x,lambda,alphas)
%perform the line search  
if ~exist('alphas','var')
  alphas = linspace(0,1,10);
end
bestw = w;
bestobj = 100000000;
r1 = y'.*(w(1:end-1)'*x+w(end));
r2 = y'.*(oldw(1:end-1)'*x+w(end));
n1 = sum(w(1:end-1).^2);
n2 = sum(oldw(1:end-1).^2);
ip = w(1:end-1)'*oldw(1:end-1);
for q = 1:length(alphas)
  alpha = alphas(q);
  
  newobj(q) = lambda/2*alpha*alpha*n1+(1-alpha).^2*n2+2*alpha*(1-alpha)*ip ...
      + sum(hinge(r1*alpha+(1-alpha)*r2));
  
  if (newobj(q) < bestobj)
    bestw = alpha*w+(1-alpha)*oldw;
    bestobj = newobj(q);
  end
end

w = bestw;
