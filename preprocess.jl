import CSV
using DataFrames
using Statistics
using PyCall
plt = pyimport("matplotlib.pyplot")

function loadfile(path)
    data = CSV.read(path) 
end

function loadall(base)
    result = Nothing
    for (root, dirs, files) in walkdir(base)
        for file in files
            path = root * "/" * file
            if result == Nothing
                result = loadfile(path)
            else
                result = vcat(result,loadfile(path))
            end
        end
    end
    return result
end

function fixpolygons(data)
    polygons = data[:,1]
    extracted = map(x->x[1],match.(r"MULTIPOLYGON \(\(\((.+)\)\)\)", polygons))
    coordinatesstrings = map(x->split.(split(x,", ")," "), extracted)
    coordinates = map(x->map(y->map(z->parse(Float64,z),y),x),coordinatesstrings)
    midpoints = map(x->(mean(map(y->y[1],x)),mean(map(y->y[2],x))),coordinates)
    xs = map(x->x[1],midpoints)
    ys = map(x->x[2],midpoints)
    return hcat((xs,ys,data[:,3],data[:,4])...)
end

function filteryear(data,year)
    return data[data[:,4] .== year, :]
end

function loaddepartamentos()
    raw =  CSV.read("departamentos.csv")
    names = raw[:,2]
    xs = raw[:,4]
    ys = raw[:,3]
    return hcat((xs,ys,names)...)
end

function countdepartamentos(departamentos, datos)
    departscount = Dict()
    departsloc = Dict()
    for i2 in 1:size(departamentos)[1]
        departscount[departamentos[i2,3]] = 0
        departsloc[departamentos[i2,3]] = Vector()
    end
    for i in 1:size(datos)[1]
        lowestdist = 99999999999
        lowestdep = ""
        for i2 in 1:size(departamentos)[1]
            deltax = datos[i,1] - departamentos[i2,1]
            deltay = datos[i,2] - departamentos[i2,2]
            distancia = √(deltax^2 + deltay^2)
            if distancia < lowestdist
                lowestdist = distancia
                lowestdep = departamentos[i2,3]
            end
        end
        #append!(departsloc[lowestdep],(datos[i,1],datos[i,2]))
        departscount[lowestdep] += datos[i,3]
    end
    return departsloc, departscount
end

function colorlerp(a,b,t)
    return a .+ (b .- a) .* t
end

function graficardeps(depslocs, departscount)
    maxcount = max(values(departscount)...)
    for key in keys(depslocs)
        val = depslocs[key]
        count = departscount[key]
        xs = val[1:2:length(val)]
        ys = val[2:2:length(val)]
        plt.scatter(xs, ys, color=colorlerp((0,1,0),(1,0,0),count/maxcount))
    end
end

function guardaraños(datos)
    departamentos = loaddepartamentos()
    for year in 2001:2019
        println(year)
        datosyear = filteryear(datos,year)
        departsloc, departscount = countdepartamentos(departamentos,datosyear)
        graficardeps(depslocs, departscount)
        plt.savefig(string(year) * ".png")
    end
end

Base.transpose(a::String) = a 

function guardaraños(datos)
    departamentos = loaddepartamentos()
    departscountall = Dict()
    for year in 2001:2019
        println(year)
        datosyear = filteryear(datos,year)
        departsloc, departscount = countdepartamentos(departamentos,datosyear)
        for key in keys(departscount)
            if !haskey(departscountall,key)
                departscountall[key] = Vector()
            end
            append!(departscountall[key],departscount[key])
        end
    end
    return vcat(transpose(collect(keys(departscountall))),hcat(values(departscountall)...))
end

function graficaraños(años)
    for j in 1:size(años)[2]
        series = años[2:size(años)[1],j]
        name = años[1,j]
        plt.plot(series)
    end
    plt.show()
end

function valueatrisk(datos)
    return quantile(vec(datos*-1),0.95)
end

function cvalueatrisk(datos)
    var = valueatrisk(datos)
    inside = filter(x->x > var,datos*-1)
    return mean(inside)
end

function punto5(datos)
    pesosiniciales = rand(1:1000000000,(size(datos)[2],1000000)) 
    pesos = [ pesosiniciales[i,j]/(sum(pesosiniciales[:,j])) for 
        i=1:size(datos)[2], j = 1:size(pesosiniciales)[2] ]
    #sumas = [ sum(pesos[:,j]) for i = [ 1 ], j = 1:size(pesos)[2] ]
    resultados = datos * pesos
    rentabilidades = [ mean(resultados[:,j]) for i = [ 1 ], 
        j = 1:size(resultados)[2] ]
    riesgos = [ 1/std(resultados[:,j]) for i = [ 1 ], 
        j = 1:size(resultados)[2] ]
    plt.scatter(riesgos', rentabilidades',s=1)

    # Mejor dsvdt
    minrisk = min(riesgos...)
    mejorriesgo = findall(x->x==minrisk, riesgos)
    plt.scatter(riesgos[mejorriesgo], rentabilidades[mejorriesgo], label="Mejor desviación estándar")
    println(mejorriesgo)
    mejorstd = mejorriesgo[1]

    plt.xlabel("Riesgo")
    plt.ylabel("Rentabilidad")
    plt.legend()
    plt.show()

    return pesos[:,mejorstd[2]]
end

function drawportfolio(años)
    labels = años[1,:]
    data = años[2:size(años)[1],:]
    weights = punto5(data)
    collected = [(labels[i],weights[i]) for i in 1:length(weights)]
    sorted = sort(collected, by=x->x[2])
    slabels = map(x->x[1],sorted)
    sweights = map(x->x[2],sorted)
    plt.pie(sweights,labels=slabels)
    plt.show()
end